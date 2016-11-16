from extractor import Extractor
import fabric.api


extractor = Extractor()

results_dir = "tmp/local"
memaslap_summary_filename = "memaslap_stats.csv"

# Extract logs
extractor.summarise_trace_logs(logs_pattern="{}/memaslap*.out".format(results_dir),
                               csv_path="{}/{}".format(results_dir, memaslap_summary_filename))
# Plot graphs
with fabric.api.settings(warn_only=True):
    fabric.api.local("sh scripts/test_local.sh")
    fabric.api.local("cp log/main.log {}".format(results_dir))
    fabric.api.local("cp log/request.log {}".format(results_dir))
    fabric.api.local("mkdir {}/graphs".format(results_dir))
    fabric.api.local("Rscript scripts/r/trace.r {} 0".format(results_dir))