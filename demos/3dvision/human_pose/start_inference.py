#!/usr/bin/env python3
import os
import subprocess
import logging
from threading import Thread
from queue import Queue
import shlex
import time
import argparse
import cv2
import numpy as np
import re
from matplotlib import pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from tkinter import *
from mttkinter import *
from dataclasses import dataclass
from logger_formatter import ColoredLoggerFormatter
logger = logging.getLogger(__file__)
logger.setLevel(level=logging.INFO)
formatter = ColoredLoggerFormatter()
formatter.add_to(logger, level=logging.INFO)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HUMAN_BLEND_FILE = os.path.join(SCRIPT_DIR, "HumanKTH283.blend")
BODY_SIM_SERVER_FILE = os.path.join(SCRIPT_DIR, "body_simulator_server.py")
POSE_PROGRAM_FILE = os.path.join(SCRIPT_DIR, "pose_program.jl")

@dataclass
class VisualizationElements(object):
    """Elements to be updated for the visualization."""
    def __init__(self, window: Tk, message_queue: Queue,
        width: int = 400, height: int = 300, dpi: float = 100.0, init_image: np.ndarray = None):
        self._window = window
        self._fig = plt.figure(figsize=(width/dpi, height/dpi), dpi=dpi)
        self._canvas = FigureCanvasTkAgg(self._fig, master=self._window)
        self._canvas.get_tk_widget().pack()
        self._axis_subplot = self._fig.add_subplot(111)
        if init_image is None:
            init_image = np.full((width, height, 3), 255, dtype=np.uint8)
        self._axis = self._axis_subplot.imshow(init_image)
        plt.xticks([])
        plt.yticks([])
        plt.margins(0, 0)
        self._fig.tight_layout()
        self._queue = message_queue
        self._queue.put("update")

    def update_image(self, image: np.ndarray):
        self._axis.set_data(image)
        self._queue.put("update")


def get_pid(name):
    """Get PID by name of program."""
    try:
        return subprocess.check_output(["pidof", name]).strip().decode('utf-8')
    except:
        return None


def run_process(command: str, queue: Queue = None):
    """Spawn a new process to run a command."""
    p = subprocess.Popen(
        shlex.split(command),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    )
    while True:
        # returns None while subprocess is running
        return_code = p.poll()
        line = p.stdout.readline().decode('utf-8')
        yield line
        if return_code is not None:
            if queue is not None:
                queue.put("finished")
            break

def run_body_simulation_server(
        command: str,
        sample_directory: str,
        plot_elements: VisualizationElements = None, 
        debug_server: bool = False
    ) -> None:
    """Routine to run blender and the body simulation server."""
    show_progress = plot_elements is not None
    if show_progress:
        orig_img = cv2.imread(f"{sample_directory}/original.png")
    for line in run_process(command):
        if debug_server:
            print(line, end='', flush=True)
        if show_progress:
            match = re.search(r'(\w+).png', line)
            if match:
                filename = match.group(0)
                try:
                    img = cv2.imread(f"{sample_directory}/{filename}")
                    frame = cv2.addWeighted(img, 0.5, orig_img, 0.5, 0)
                    plot_elements.update_image(frame)
                except:
                    pass

def run_julia_program(command: str, queue: Queue) -> None:
     """Routine to run Julia program."""
     for line in run_process(command, queue):
        print(line, end='', flush=True)

def infer(figure_path, port=5000, debug_server=False):
    figure_path = os.path.abspath(os.path.expanduser(figure_path))
    if not os.path.exists(figure_path):
        logger.error("File %s does not exist.", figure_path)
        raise FileNotFoundError(f"File {figure_path} does not exist.")
    subdir = figure_path.split('/')[-1].replace('.png', '')
    samples_base_dir = os.path.abspath(os.path.expanduser("samples"))
    samples_dir = os.path.join(samples_base_dir, subdir)
    try:
        if not os.path.isdir(samples_base_dir):
            os.makedirs(samples_base_dir)
            logger.info("Directory '%s' created.", samples_base_dir)
        if not os.path.isdir(samples_dir):
            os.mkdir(samples_dir)
            logger.info("Subdirectory '%s' created.", samples_dir)
    except:
        pass

    try:
        sample_directory = samples_dir
        if not os.path.isdir(sample_directory):
            os.mkdir(sample_directory)
            logger.info("Subdirectory '%s' created.", sample_directory)
        logger.info(
            "Subdirectory '%s' set as sample directory.", sample_directory)
        output = subprocess.check_output(
            ["cp", figure_path, f"{sample_directory}/original.png"]
        ).strip().decode('utf-8')
        if output:
            logger.info(output)
    except:
        logger.error("Sample directory could not be created or set.")
        raise RuntimeError("Sample directory could not be created or set.")

    window = Tk()
    window.protocol("WM_DELETE_WINDOW", window.destroy)
    process_queue = Queue(1)
    message_queue = Queue()

    # Open original figure
    orig_img = cv2.imread(f"{sample_directory}/original.png")
    visualizaton_elements = VisualizationElements(
        window=window,
        message_queue=message_queue,
        width=800,
        height=600,
        dpi=100.0,
        init_image=orig_img
    )

    # Start body simulation server
    command = f"blender {HUMAN_BLEND_FILE} -P {BODY_SIM_SERVER_FILE} --port {port}"
    server_thread = Thread(
        target=run_body_simulation_server,
        args=(command, sample_directory, visualizaton_elements, debug_server),
        daemon=True
    )
    server_thread.start()

    # Get PID
    blender_pid = get_pid("blender")
    logger.info(f"Body simulation server process started with PID {blender_pid}")
    # Launches Julia process
    logger.info("Launching Julia program...")
    command = f"julia {POSE_PROGRAM_FILE} {figure_path} {sample_directory} {port}"
    program_thread = Thread(
        target=run_julia_program,
        args=(command, process_queue),
        daemon=True
    )
    program_thread.start()

    # Main loop for visualization
    while process_queue.empty():
        update_signal = message_queue.get(block=True)
        if update_signal == "update":
            visualizaton_elements._fig.canvas.draw()
            window.update_idletasks()
        else:
            break

    return_code = subprocess.call(
        shlex.split(f"kill -9 {blender_pid}"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    if return_code:
        logger.info("Inference terminated cleanly.")
    server_thread.join()
    program_thread.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Start inference script")
    parser.add_argument("--figure-path", "-f", type=str,
                        default="examples/small/test.png")
    parser.add_argument("--port", "-p", type=int, default=5000)
    args = parser.parse_args()
    infer(figure_path=args.figure_path, port=args.port)
