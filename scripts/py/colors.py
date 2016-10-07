class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

    @staticmethod
    def ok_blue(s):
        return Colors.OKBLUE + s + Colors.ENDC

    @staticmethod
    def ok_green(s):
        return Colors.OKGREEN + s + Colors.ENDC

    @staticmethod
    def warning(s):
        return Colors.WARNING + s + Colors.ENDC

    @staticmethod
    def fail(s):
        return Colors.FAIL + s + Colors.ENDC

    @staticmethod
    def bold(s):
        return Colors.BOLD + s + Colors.ENDC

    @staticmethod
    def underline(s):
        return Colors.UNDERLINE + s + Colors.ENDC