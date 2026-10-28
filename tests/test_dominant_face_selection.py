from app.tasks.face_recognition_tasks import _select_dominant_face


def _face(w: int, h: int, tag: str = "x") -> dict:
    return {"facial_area": {"x": 0, "y": 0, "w": w, "h": h}, "embedding": [1.0], "tag": tag}


def test_single_face_is_returned():
    face = _face(200, 200)
    assert _select_dominant_face([face]) is face


def test_dominant_face_wins_over_small_false_positives():
    main = _face(400, 450, "main")
    noise = [_face(60, 60), _face(80, 70), _face(50, 50)]
    assert _select_dominant_face([noise[0], main, *noise[1:]]) is main


def test_two_similar_faces_are_ambiguous():
    assert _select_dominant_face([_face(300, 300), _face(280, 290)]) is None


def test_faces_without_area_are_ambiguous():
    no_area = {"embedding": [1.0]}
    assert _select_dominant_face([no_area, dict(no_area)]) is None
