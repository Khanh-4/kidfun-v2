import numpy as np
import pandas as pd
import pytest

from models.significance import cluster_bootstrap, holm, paired_wilcoxon, per_subject_mae


def _preds(n_subjects=30, rows=10, seed=0, gap=5.0):
    """Mô hình 'good' lệch ít hơn 'base' một khoảng `gap` phút ở mọi trẻ."""
    rng = np.random.default_rng(seed)
    pid = np.repeat(np.arange(n_subjects), rows)
    y = rng.uniform(60, 240, len(pid))
    noise = rng.normal(0, 3, len(pid))
    return pd.DataFrame({
        "profileId": pid,
        "y_next": y,
        "good": y + 10 + noise,
        "base": y + 10 + gap + noise,
    })


def test_per_subject_mae_one_row_per_subject():
    table = per_subject_mae(_preds(n_subjects=4, rows=3), ["good", "base"])
    assert list(table.index) == [0, 1, 2, 3]
    assert (table["base"] > table["good"]).all()


def test_wilcoxon_detects_consistent_improvement():
    res = paired_wilcoxon(per_subject_mae(_preds(), ["good", "base"]), "good", "base")
    assert res["n"] == 30
    assert res["wins"] == 30
    assert res["median_diff"] == pytest.approx(-5, abs=1.5)
    assert res["p"] < 1e-4


def test_wilcoxon_no_difference_gives_large_p():
    res = paired_wilcoxon(per_subject_mae(_preds(gap=0.0), ["good", "base"]), "good", "base")
    assert res["median_diff"] == pytest.approx(0)
    assert res["p"] == pytest.approx(1.0)


def test_wilcoxon_skips_subjects_without_prediction():
    """Người không có dự đoán nào của một mô hình (MAE NaN) bị bỏ khỏi cặp, p vẫn là số."""
    table = per_subject_mae(_preds(), ["good", "base"])
    table.loc[[0, 1], "base"] = np.nan
    res = paired_wilcoxon(table, "good", "base")
    assert res["n"] == 28
    assert np.isfinite(res["p"]) and res["p"] < 1e-4


def test_holm_is_monotone_and_capped():
    adj = holm([0.01, 0.04, 0.03])
    assert adj == pytest.approx([0.03, 0.06, 0.06])
    assert holm([0.9, 0.8]) == pytest.approx([1.0, 1.0])


def test_cluster_bootstrap_ci_contains_point_and_is_reproducible():
    frame = _preds()

    def mae(f):
        return np.array([(f["good"] - f["y_next"]).abs().mean()])

    point, lo, hi = cluster_bootstrap(frame, "profileId", mae, n_boot=300, seed=1)
    again = cluster_bootstrap(frame, "profileId", mae, n_boot=300, seed=1)
    assert lo[0] <= point[0] <= hi[0]
    assert hi[0] - lo[0] < 2
    assert np.allclose(lo, again[1]) and np.allclose(hi, again[2])


def test_cluster_bootstrap_resamples_whole_subjects():
    """Mỗi trẻ có một giá trị hằng → mọi mẫu bootstrap chỉ lấy được các giá trị đó, không trộn trong trẻ."""
    frame = pd.DataFrame({"profileId": np.repeat([0, 1, 2], 5), "v": np.repeat([1.0, 2.0, 3.0], 5)})
    seen = []

    def stat(f):
        seen.append(f.groupby("profileId", sort=False)["v"].nunique().max())
        return np.array([f["v"].mean()])

    point, lo, hi = cluster_bootstrap(frame, "profileId", stat, n_boot=50, seed=0)
    assert point[0] == pytest.approx(2.0)
    assert 1.0 <= lo[0] <= hi[0] <= 3.0
    assert max(seen) == 1
