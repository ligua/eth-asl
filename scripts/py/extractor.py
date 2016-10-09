import csv
import glob
import re

class Extractor:

    re_filename = re.compile(r".*\/baseline_memaslap(\d)_conc(\d{3})_rep(\d{2}).out")
    re_total_events = re.compile(r"Total Statistics \((\d+) events\)")

    DELIMITER = ";"

    @staticmethod
    def summarise_baseline_logs(logs_pattern="results/baseline/*.out", csv_path="results/baseline/aggregated.csv"):
        with open(csv_path, "w") as csv_file:
            csv_writer = csv.writer(csv_file, delimiter = Extractor.DELIMITER)

            # Header
            csv_writer.writerow([]) # TODO

            filenames = glob.glob(logs_pattern)
            for filename in filenames:
                with open(filename) as log_file:

                    print(filename)

                    groups = Extractor.re_filename.search(filename).groups()
                    client_no = int(groups[0])
                    concurrency = int(groups[1])
                    repetition = int(groups[2])
                    #print(client_no, concurrency, repetition)

                    for line in log_file:
                        if Extractor.re_total_events.match(line):
                            total_events = int(Extractor.re_total_events.search(line).group(1))







if __name__ == "__main__":
    e = Extractor()
    e.summarise_baseline_logs(logs_pattern="results/baseline/backuptaivo/*.out")