"""LSTM cho M1 — một mô hình chung cho mọi trẻ.

Đầu vào mỗi dòng (ngày t):
  - chuỗi 14 ngày đầy đủ t−14..t−1: [phút / scale, cờ thiếu, dow_sin, dow_cos, ngày học, ngày nghỉ];
  - véc-tơ ngữ cảnh ngày t+1 và phần đã dùng trong ngày t (trước 21:00).
Dự đoán tỷ lệ y_next / scale, với scale = mức thường ngày của chính trẻ (mean14 → mean7 → y_lag1).
Chỉ dùng tổng của các ngày <= t−1 (đã biết lúc 21:00 ngày t) -> không rò rỉ.
"""

import numpy as np
import pandas as pd
import torch
from torch import nn

from features import Calendar

SEQ_DAYS = 14
STEP_FEATURES = 6
CONTEXT = ("dow_sin", "dow_cos", "is_school_day", "is_weekend", "is_holiday", "is_summer", "is_exam_period", "has_limit")
MIN_SCALE = 10.0
EPOCHS, BATCH, HIDDEN, LR = 12, 256, 32, 1e-3
torch.set_num_threads(4)


class _Net(nn.Module):
    def __init__(self, n_context: int):
        super().__init__()
        self.lstm = nn.LSTM(STEP_FEATURES, HIDDEN, batch_first=True)
        self.head = nn.Sequential(nn.Linear(HIDDEN + n_context, 32), nn.ReLU(), nn.Linear(32, 1))

    def forward(self, seq, ctx):
        _, (h, _) = self.lstm(seq)
        return self.head(torch.cat([h[-1], ctx], dim=1)).squeeze(1)


class LSTMGlobal:
    name = "lstm"
    REFIT_FOLDS = 4  # huấn luyện lại mỗi 4 tuần kiểm tra (huấn luyện mạng tốn thời gian hơn XGBoost)

    def attach(self, daily: pd.DataFrame) -> "LSTMGlobal":
        """Dựng sẵn chuỗi cho mọi dòng của bảng đặc trưng (cần lịch sử cả ngoài tập train/test)."""
        self.scale = (
            daily["mean14"].fillna(daily["mean7"]).fillna(daily["y_lag1"]).fillna(60.0).clip(lower=MIN_SCALE)
        )
        self.seq = pd.Series([None] * len(daily), index=daily.index, dtype=object)
        cal = Calendar.load()
        for _, g in daily.groupby("profileId"):
            dates = pd.date_range(g["date"].min() - pd.Timedelta(days=SEQ_DAYS), g["date"].max())
            totals = pd.Series(g["y_next"].to_numpy(), index=g["target_date"]).reindex(dates)
            flags = cal.day_flags(dates)
            angle = 2 * np.pi * flags["dow"].to_numpy() / 7
            off = (flags["day_type"] == "off").to_numpy()
            steps = np.column_stack(
                [totals.to_numpy(), totals.isna().to_numpy(), np.sin(angle), np.cos(angle),
                 flags["is_school_day"].to_numpy(), off]
            ).astype(float)
            pos = {d: i for i, d in enumerate(dates)}
            for row, day in zip(g.index, g["date"]):
                end = pos[day]  # các ngày t−14..t−1
                window = steps[end - SEQ_DAYS : end].copy()
                window[:, 0] = np.nan_to_num(window[:, 0] / self.scale[row])
                self.seq[row] = window
        return self

    def _tensors(self, df: pd.DataFrame):
        seq = torch.tensor(np.stack(self.seq[df.index].to_numpy()), dtype=torch.float32)
        scale = self.scale[df.index]
        ctx = df[list(CONTEXT)].astype(float).fillna(0).to_numpy()
        extra = np.column_stack(
            [(df["today_until_cutoff"] / scale).fillna(0), (df["limit_tomorrow"] / scale).fillna(0).clip(upper=5)]
        )
        return seq, torch.tensor(np.hstack([ctx, extra]), dtype=torch.float32)

    def fit(self, train: pd.DataFrame) -> "LSTMGlobal":
        torch.manual_seed(0)
        seq, ctx = self._tensors(train)
        scale = torch.tensor(self.scale[train.index].to_numpy(), dtype=torch.float32)
        target = torch.tensor(train["y_next"].to_numpy(), dtype=torch.float32)
        self.net = _Net(ctx.shape[1])
        opt = torch.optim.Adam(self.net.parameters(), lr=LR)
        gen = torch.Generator().manual_seed(0)
        for _ in range(EPOCHS):
            for idx in torch.randperm(len(target), generator=gen).split(BATCH):
                opt.zero_grad()
                pred = self.net(seq[idx], ctx[idx]) * scale[idx]
                loss = (pred - target[idx]).abs().mean() / 100  # L1 theo phút -> tối ưu đúng MAE
                loss.backward()
                opt.step()
        return self

    def predict(self, test: pd.DataFrame) -> np.ndarray:
        seq, ctx = self._tensors(test)
        with torch.no_grad():
            ratio = self.net(seq, ctx).clamp(min=0).numpy()
        return ratio * self.scale[test.index].to_numpy()
