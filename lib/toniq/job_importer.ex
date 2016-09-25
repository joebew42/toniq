defmodule Toniq.JobImporter do
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    {:ok, _} = :timer.send_interval job_import_interval, :import_jobs
    {:ok, state}
  end

  def handle_info(:import_jobs, state) do
    import_jobs(enabled: enabled?)
    {:noreply, state}
  end

  defp import_jobs(enabled: false), do: nil
  defp import_jobs(enabled: true) do
    incoming_jobs
    |> log_import
    |> Enum.each(&import_job/1)
  end

  defp jobs_to_import_count do
    max_count = 50 # this would be in config
    diff = max_count - Toniq.JobPersistence.jobs_count

    if diff < 0 do
      0
    else
      diff
    end
  end

  defp incoming_jobs do
    Toniq.JobPersistence.incoming_jobs(jobs_to_import_count)
  end

  defp log_import([]), do: []
  defp log_import(jobs) do
    Logger.log(:info, "#{__MODULE__}: Importing #{Enum.count(jobs)} jobs from incoming_jobs")

    jobs
  end

  def import_job(job) do
    Toniq.enqueue(job.worker, job.arguments)
    Toniq.JobPersistence.remove_from_incoming_jobs(job)
  end

  defp enabled?, do: !Application.get_env(:toniq, :disable_import)

  defp job_import_interval, do: Application.get_env(:toniq, :job_import_interval)
end
