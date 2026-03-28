from src.app.core.worker.functions import expire_no_show_bookings
from src.app.core.worker.settings import WorkerSettings


def test_worker_registers_booking_expiration_function_and_cron_job():
    assert expire_no_show_bookings in WorkerSettings.functions
    assert len(WorkerSettings.cron_jobs) == 1

    cron_job = WorkerSettings.cron_jobs[0]
    assert cron_job.coroutine is expire_no_show_bookings
    assert cron_job.second == 0
    assert cron_job.microsecond == 0
    assert cron_job.keep_result_s == 0
    assert cron_job.max_tries == 1