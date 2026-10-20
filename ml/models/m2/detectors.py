"""Bộ phát hiện bất thường M2 — cùng giao diện fit(frame) / score(frame), điểm càng cao càng bất thường.

frame là bảng theo giờ (build_hourly_features) hoặc theo ngày (build_day_anomaly_features); mỗi bộ biết
cách dựng ma trận từ frame qua hàm `matrix`. Mô hình học máy không dùng nhãn (học không giám sát).
"""

import numpy as np
import torch
from sklearn.cluster import DBSCAN
from sklearn.ensemble import IsolationForest
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import StandardScaler
from torch import nn

from .data import day_matrix, hour_matrix

# Luật tầng 1 (đặc tả 05 mục 2.3) — cũng là thứ sẽ chạy trên máy trẻ
NIGHT_MIN_MINUTES = 10
SPIKE_RATIO, SPIKE_MIN_MINUTES = 3.0, 20
NEW_APP_MIN_MINUTES = 10
DAY_RATIO_ALERT = 2.0


class HourRules:
    name = "luật tầng 1"

    def fit(self, frame):
        return self

    def score(self, h):
        base = h["base_mean"].fillna(0).clip(lower=5)
        night = (h["is_night"] | h["in_sleep_window"]) & (h["hour_min"] >= NIGHT_MIN_MINUTES)
        spike = (h["hour_min"] >= SPIKE_RATIO * base) & (h["hour_min"] >= SPIKE_MIN_MINUTES)
        new_app = h["new_app_min"].fillna(0) >= NEW_APP_MIN_MINUTES
        tie = h["hour_z"].fillna(0).clip(-50, 50) / 100  # xếp hạng trong cùng số luật vi phạm
        return (night.astype(int) + spike.astype(int) + new_app.astype(int) + tie).to_numpy()


class HourZ:
    name = "z-score"

    def fit(self, frame):
        return self

    def score(self, h):
        return h["hour_z"].fillna(0).to_numpy()


class DayRules:
    name = "luật tầng 1"

    def fit(self, frame):
        return self

    def score(self, d):
        flags = (
            (d["day_ratio"].fillna(1) >= DAY_RATIO_ALERT).astype(int)
            + (d["night_min"] >= NIGHT_MIN_MINUTES).astype(int)
            + (d["new_app_min"].fillna(0) >= NEW_APP_MIN_MINUTES).astype(int)
            + (d["yt_danger_high"] > 0).astype(int)
        )
        return (flags + d["day_ratio"].fillna(1).clip(0, 50) / 100).to_numpy()


class DayRatio:
    name = "z-score"  # mức ngày: tỷ lệ so với mức thường ngày cùng loại ngày

    def fit(self, frame):
        return self

    def score(self, d):
        return d["day_ratio"].fillna(1).to_numpy()


class IForest:
    name = "isolation forest"

    def __init__(self, matrix):
        self.matrix = matrix

    def fit(self, frame):
        self.model = IsolationForest(n_estimators=200, max_samples=4096, random_state=0, n_jobs=4)
        self.model.fit(self.matrix(frame))
        return self

    def score(self, frame):
        return -self.model.score_samples(self.matrix(frame))


class _AE(nn.Module):
    def __init__(self, d):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(d, 16), nn.ReLU(), nn.Linear(16, 6), nn.ReLU(), nn.Linear(6, 16), nn.ReLU(), nn.Linear(16, d)
        )

    def forward(self, x):
        return self.net(x)


class Autoencoder:
    """Autoencoder nhỏ; điểm = sai số tái tạo (MSE) trên đặc trưng đã chuẩn hoá."""

    name = "autoencoder"
    EPOCHS, BATCH, LR = 8, 512, 1e-3

    def __init__(self, matrix):
        self.matrix = matrix

    def _x(self, frame):
        x = np.clip(self.scaler.transform(self.matrix(frame)), -10, 10)
        return torch.tensor(x, dtype=torch.float32)

    def fit(self, frame):
        torch.manual_seed(0)
        self.scaler = StandardScaler().fit(self.matrix(frame))
        x = self._x(frame)
        self.net = _AE(x.shape[1])
        opt = torch.optim.Adam(self.net.parameters(), lr=self.LR)
        gen = torch.Generator().manual_seed(0)
        for _ in range(self.EPOCHS):
            for idx in torch.randperm(len(x), generator=gen).split(self.BATCH):
                opt.zero_grad()
                loss = ((self.net(x[idx]) - x[idx]) ** 2).mean()
                loss.backward()
                opt.step()
        return self

    def score(self, frame):
        x = self._x(frame)
        with torch.no_grad():
            return ((self.net(x) - x) ** 2).mean(dim=1).numpy()


class DBSCANDistance:
    """DBSCAN không có predict: học các điểm lõi trên tập huấn luyện, điểm mới càng xa điểm lõi gần nhất càng
    bất thường (> eps = nhiễu theo DBSCAN). eps = phân vị 95 của khoảng cách tới láng giềng thứ MIN_SAMPLES."""

    name = "dbscan"
    MIN_SAMPLES, MAX_FIT_ROWS = 10, 15000

    def __init__(self, matrix):
        self.matrix = matrix

    def fit(self, frame):
        x = self.matrix(frame)
        self.scaler = StandardScaler().fit(x)
        z = self.scaler.transform(x)
        if len(z) > self.MAX_FIT_ROWS:
            z = z[np.random.default_rng(0).choice(len(z), self.MAX_FIT_ROWS, replace=False)]
        dist, _ = NearestNeighbors(n_neighbors=self.MIN_SAMPLES).fit(z).kneighbors(z)
        self.eps = float(np.quantile(dist[:, -1], 0.95))
        db = DBSCAN(eps=self.eps, min_samples=self.MIN_SAMPLES).fit(z)
        self.core = NearestNeighbors(n_neighbors=1).fit(z[db.core_sample_indices_])
        return self

    def score(self, frame):
        dist, _ = self.core.kneighbors(self.scaler.transform(self.matrix(frame)))
        return dist[:, 0]


def hour_detectors():
    return [HourRules(), HourZ(), IForest(hour_matrix), Autoencoder(hour_matrix)]


def day_detectors():
    return [DayRules(), DayRatio(), IForest(day_matrix), DBSCANDistance(day_matrix), Autoencoder(day_matrix)]
