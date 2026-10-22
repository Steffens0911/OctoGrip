"""Rotação aleatória diária do vídeo da tarefa diária (sem acesso ao banco)."""

from datetime import date, timedelta
from types import SimpleNamespace

from app.services.training_video_service import pick_daily_video

START = date(2026, 10, 1)


def _videos(n: int) -> list:
    return [SimpleNamespace(id=i) for i in range(n)]


def test_single_video_always_chosen():
    videos = _videos(1)
    for offset in range(10):
        assert pick_daily_video(videos, scope_key="a", today=START + timedelta(days=offset)) is videos[0]


def test_same_day_same_video_for_everyone():
    videos = _videos(5)
    first = pick_daily_video(videos, scope_key="academia-1", today=START)
    assert all(pick_daily_video(videos, scope_key="academia-1", today=START) is first for _ in range(20))


def test_never_repeats_previous_day():
    videos = _videos(3)
    previous = None
    for offset in range(200):
        chosen = pick_daily_video(videos, scope_key="academia-1", today=START + timedelta(days=offset))
        assert chosen is not previous
        previous = chosen


def test_two_videos_alternate():
    videos = _videos(2)
    picks = [pick_daily_video(videos, scope_key="x", today=START + timedelta(days=d)).id for d in range(10)]
    assert all(a != b for a, b in zip(picks, picks[1:], strict=False))


def test_rotation_is_not_sequential_and_uses_all_videos():
    videos = _videos(4)
    picks = [pick_daily_video(videos, scope_key="academia-1", today=START + timedelta(days=d)).id for d in range(60)]
    assert set(picks) == {0, 1, 2, 3}
    sequential = [(picks[0] + d) % 4 for d in range(60)]
    assert picks != sequential


def test_different_academies_do_not_share_the_same_sequence():
    videos = _videos(6)
    days = [START + timedelta(days=d) for d in range(30)]
    a = [pick_daily_video(videos, scope_key="academia-a", today=d).id for d in days]
    b = [pick_daily_video(videos, scope_key="academia-b", today=d).id for d in days]
    assert a != b


def test_no_consecutive_repeat_for_any_list_size_and_every_video_appears_per_cycle():
    for size in range(2, 9):
        videos = _videos(size)
        picks = [
            pick_daily_video(videos, scope_key="academia-1", today=START + timedelta(days=d)).id
            for d in range(size * 40)
        ]
        assert all(a != b for a, b in zip(picks, picks[1:], strict=False)), size
        first_ordinal = START.toordinal()
        cycle_start = (-first_ordinal) % size
        for i in range(cycle_start, len(picks) - size, size):
            assert set(picks[i : i + size]) == set(range(size)), (size, i)
