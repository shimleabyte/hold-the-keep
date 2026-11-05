extends RefCounted
## Pure visual scale mapping from enemy data; combat stats and hitboxes are unchanged.


static func from_data(data: Dictionary) -> Vector2:
    return Vector2.ONE * float(data.get("scale", 1.0))
