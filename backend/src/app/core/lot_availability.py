from datetime import UTC, datetime
from queue import Empty, Full, Queue
from threading import Lock

from ..models.parking import ParkingLot
from ..schemas.parking_lot import ParkingLotAvailabilityEventRead


class LotAvailabilityHub:
    def __init__(self, max_queue_size: int = 32) -> None:
        self._max_queue_size = max_queue_size
        self._lock = Lock()
        self._subscribers: set[Queue[ParkingLotAvailabilityEventRead]] = set()

    def subscribe(self) -> Queue[ParkingLotAvailabilityEventRead]:
        subscription: Queue[ParkingLotAvailabilityEventRead] = Queue(
            maxsize=self._max_queue_size
        )
        with self._lock:
            self._subscribers.add(subscription)
        return subscription

    def unsubscribe(self, subscription: Queue[ParkingLotAvailabilityEventRead]) -> None:
        with self._lock:
            self._subscribers.discard(subscription)

    def publish(self, event: ParkingLotAvailabilityEventRead) -> None:
        with self._lock:
            subscribers = tuple(self._subscribers)

        for subscription in subscribers:
            try:
                subscription.put_nowait(event)
            except Full:
                try:
                    subscription.get_nowait()
                except Empty:
                    pass
                try:
                    subscription.put_nowait(event)
                except Full:
                    continue


lot_availability_hub = LotAvailabilityHub()


def build_lot_availability_event(
    parking_lot: ParkingLot,
    *,
    previous_current_available: int,
    source: str,
    occurred_at: datetime | None = None,
) -> ParkingLotAvailabilityEventRead:
    current_available = max(int(parking_lot.current_available), 0)
    previous_available = max(int(previous_current_available), 0)
    emitted_at = occurred_at or datetime.now(UTC)
    return ParkingLotAvailabilityEventRead(
        lot_id=int(parking_lot.id),
        current_available=current_available,
        previous_current_available=previous_available,
        is_full=current_available <= 0,
        was_full=previous_available <= 0,
        source=source,
        occurred_at=emitted_at,
    )


def publish_lot_availability_update(
    parking_lot: ParkingLot,
    *,
    previous_current_available: int,
    source: str,
) -> ParkingLotAvailabilityEventRead | None:
    event = build_lot_availability_event(
        parking_lot,
        previous_current_available=previous_current_available,
        source=source,
    )
    if event.current_available == event.previous_current_available:
        return None

    lot_availability_hub.publish(event)
    return event