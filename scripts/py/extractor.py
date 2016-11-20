import csv
import glob
import re

class Extractor:

    re_baseline_memaslap_filename = re.compile(r".*\/baseline_memaslap(\d)_conc(\d{3})_rep(\d{2}).out")
    re_trace_memaslap_filename = re.compile(r".*\/memaslap(\d).out")
    re_total_events = re.compile(r"Total Statistics \((\d+) events\)")
    re_total_get_events = re.compile(r"Get Statistics \((\d+) events\)")
    re_total_set_events = re.compile(r"Set Statistics \((\d+) events\)")
    re_get_misses = re.compile(r"^get_misses: (\d+)")
    re_last_line = re.compile(r"Run time: (\d+\.\d+)s Ops: (\d+) TPS: (\d+) Net_rate: (\d+\.\d+)")
    re_min = re.compile(r"\s*Min:\s*(\d+)\s*")
    re_max = re.compile(r"\s*Max:\s*(\d+)\s*")
    re_avg = re.compile(r"\s*Avg:\s*(\d+)\s*")
    re_geo = re.compile(r"\s*Geo:\s*(\d+)\s*")
    re_std = re.compile(r"\s*Std:\s*(\d+)\s*")
    re_get_statistics = re.compile(r"^Get Statistics$")
    re_set_statistics = re.compile(r"^Set Statistics$")
    re_total_statistics = re.compile(r"^Total Statistics$")
    re_period_stats = re.compile(r"^Period\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s*")
    re_global_stats = re.compile(r"^Global\s+(\d+).*")

    DELIMITER = ";"

    @staticmethod
    def summarise_baseline_logs(logs_pattern="results/baseline/*.out", csv_path="results/baseline/aggregated.csv"):
        with open(csv_path, "w") as csv_file:
            csv_writer = csv.writer(csv_file, delimiter = Extractor.DELIMITER)

            # Header
            csv_writer.writerow(["filename", "client_no", "concurrency", "repetition", "total_events", "run_time",
                                     "ops", "tps", "net_rate", "tmin", "tmax", "tavg", "tgeo", "tstd"])

            filenames = glob.glob(logs_pattern)
            for filename in filenames:
                total_line_passed = False

                with open(filename) as log_file:

                    print(filename)

                    groups = Extractor.re_baseline_memaslap_filename.search(filename).groups()
                    client_no = int(groups[0])
                    concurrency = int(groups[1])
                    repetition = int(groups[2])

                    for line in log_file:
                        if Extractor.re_total_events.match(line):
                            total_events = Extractor.re_total_events.search(line).group(1)
                            total_line_passed = True
                        elif Extractor.re_last_line.match(line):
                            groups = Extractor.re_last_line.search(line).groups()
                            run_time = groups[0]
                            ops = groups[1]
                            tps = groups[2]
                            net_rate = groups[3]
                        elif total_line_passed:
                            if Extractor.re_min.match(line):
                                tmin = Extractor.re_min.search(line).groups()[0]
                            elif Extractor.re_max.match(line):
                                tmax = Extractor.re_max.search(line).groups()[0]
                            elif Extractor.re_avg.match(line):
                                tavg = Extractor.re_avg.search(line).groups()[0]
                            elif Extractor.re_geo.match(line):
                                tgeo = Extractor.re_geo.search(line).groups()[0]
                            elif Extractor.re_std.match(line):
                                tstd = Extractor.re_std.search(line).groups()[0]

                row = [filename, client_no, concurrency, repetition, total_events, run_time,
                                     ops, tps, net_rate, tmin, tmax, tavg, tgeo, tstd]
                csv_writer.writerow(row)


    @staticmethod
    def summarise_trace_logs(logs_pattern="results/trace/memaslap*.out", csv_path="results/trace/memaslap_stats.csv"):
        with open(csv_path, "w") as csv_file:
            csv_writer = csv.writer(csv_file, delimiter=Extractor.DELIMITER)

            # Header
            csv_writer.writerow(["memaslap_number", "type", "request_type", "time", "ops", "tps", "get_misses", "min", "max", "avg", "std"])

            filenames = glob.glob(logs_pattern)
            for filename in filenames:
                total_line_passed = False
                memaslap_number = Extractor.re_trace_memaslap_filename.search(filename).groups()[0]

                with open(filename) as log_file:

                    has_set_summary = False

                    for line in log_file:
                        if not total_line_passed:
                            type = "t"

                            if Extractor.re_total_get_events.match(line):
                                total_line_passed = True
                                request_type = "GET"
                            elif Extractor.re_get_statistics.match(line):
                                request_type = "GET"
                            elif Extractor.re_set_statistics.match(line):
                                request_type = "SET"
                            elif Extractor.re_total_statistics.match(line):
                                request_type = None
                            elif Extractor.re_period_stats.match(line):
                                s = Extractor.re_period_stats.search(line).groups()
                                ops = s[1]
                                tps = s[2]
                                get_misses = s[4]
                                min = s[5]
                                max = s[6]
                                avg = s[7]
                                std = s[8]
                            elif Extractor.re_global_stats.match(line) and request_type:
                                s = Extractor.re_global_stats.search(line).groups()
                                time = s[0]
                                row = [memaslap_number, type, request_type, time, ops, tps, get_misses, min, max, avg, std]
                                csv_writer.writerow(row)
                        else:
                            type = "global"
                            if Extractor.re_total_set_events.match(line) or Extractor.re_total_events.match(line):
                                if Extractor.re_total_set_events.match(line):
                                    has_set_summary = True

                                row_get = [memaslap_number, type, "GET", "NA", ops, tps, "NA", min, max,
                                       avg, std]
                                csv_writer.writerow(row)
                                request_type = "SET"

                            elif Extractor.re_min.match(line):
                                min = Extractor.re_min.search(line).groups()[0]
                            elif Extractor.re_max.match(line):
                                max = Extractor.re_max.search(line).groups()[0]
                            elif Extractor.re_avg.match(line):
                                avg = Extractor.re_avg.search(line).groups()[0]
                            elif Extractor.re_std.match(line):
                                std = Extractor.re_std.search(line).groups()[0]
                            elif Extractor.re_get_misses.match(line):
                                get_misses = Extractor.re_get_misses.search(line).groups()[0]
                            elif Extractor.re_last_line.match(line):
                                groups = Extractor.re_last_line.search(line).groups()
                                ops = groups[1]
                                tps = groups[2]

                                run_time = groups[0]
                                row_set = [memaslap_number, type, request_type, run_time, ops, tps, get_misses, min, max, avg,
                                       std]
                                row_get[3] = run_time       # TODO if I add stuff to beginning, this will fail silently
                                row_get[6] = get_misses
                                csv_writer.writerow(row_get)
                                if has_set_summary:
                                    csv_writer.writerow(row_set)

                    print(filename)


if __name__ == "__main__":
    e = Extractor()

    for dirname in glob.glob("results/writes/S*_R*_writes*_rep*"):
        e.summarise_trace_logs(logs_pattern="{}/memaslap*.out".format(dirname),
                               csv_path="{}/memaslap_stats.csv".format(dirname))