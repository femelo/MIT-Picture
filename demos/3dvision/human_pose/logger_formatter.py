import sys
from logging import (
    Logger,
    Formatter,
    StreamHandler,
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    CRITICAL
)
from colorama import init, Fore

if sys.platform == 'win32':
    init(convert=True)

class ColoredLoggerFormatter(Formatter):
    """Logger custom formatting class"""
    cyan = Fore.CYAN
    green = Fore.GREEN
    yellow = Fore.YELLOW
    light_red = Fore.LIGHTRED_EX
    red = Fore.RED
    reset = Fore.RESET
    format1 = "[%(levelname)-8s] %(message)s"
    format2 = "[%(levelname)-8s] [%(filename)s: %(lineno)d] %(message)s"
    FORMATS = {
        DEBUG: green + format2 + reset,
        INFO: cyan + format2 + reset,
        WARNING: yellow + format2 + reset,
        ERROR: light_red + format2 + reset,
        CRITICAL: red + format2 + reset
    }

    def format(self, record):
        """Format logging record."""
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = Formatter(log_fmt)
        return formatter.format(record)
    
    def add_to(self, logger: Logger, level: int = INFO):
        """Add stream formatter to logger."""
        stream_handler = StreamHandler()
        stream_handler.setLevel(level)
        stream_handler.setFormatter(self)
        logger.addHandler(stream_handler)
