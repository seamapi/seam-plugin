from dataclasses import dataclass


@dataclass
class Room:
    id: str
    number: str
    floor: int
    type: str  # "standard", "suite", or "penthouse"
