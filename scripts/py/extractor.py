import csv
import glob
import re

class Extractor:

    re_filename = re.compile(r".*\/baseline_memaslap(\d)_conc(\d{3})_rep(\d{2}).out")
    re_total_events = re.compile(r"Total Statistics \((\d+) events\)")
    re_last_line = re.compile(r"Run time: (\d+\.\d+)s Ops: (\d+) TPS: (\d+) Net_rate: (\d+\.\d+)")
    re_min = re.compile(r"\s*Min:\s*(\d+)\s*")
    re_max = re.compile(r"\s*Max:\s*(\d+)\s*")
    re_avg = re.compile(r"\s*Avg:\s*(\d+)\s*")
    re_geo = re.compile(r"\s*Geo:\s*(\d+)\s*")
    re_std = re.compile(r"\s*Std:\s*(\d+)\s*")

    DELIMITER = ";"

    @staticmethod
    def summarise_baseline_logs(logs_pattern="results/baseline/*.out", csv_path="results/baseline/aggregated.csv"):
        with open(csv_path, "w") as csv_file:
            csv_writer = csv.writer(csv_file, delimiter = Extractor.DELIMITER)

            # Header
            csv_writer.writerow(["filename", "client_no", "concurrency", "repetition", "total_events", "run_time",
                                     "ops", "tps", "net_rate", "tmin", "tmax", "tavg", "tgeo", "tstd"])

            total_line_passed = False

            filenames = glob.glob(logs_pattern)
            for filename in filenames:
                with open(filename) as log_file:

                    print(filename)

                    groups = Extractor.re_filename.search(filename).groups()
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







if __name__ == "__main__":
    e = Extractor()
    e.summarise_baseline_logs(logs_pattern="results/baseline/*.out")