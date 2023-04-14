#!/usr/bin/env python3
import os
import subprocess
import logging
from threading import Thread
import shlex
import time
import argparse
from logger_formatter import ColoredLoggerFormatter
logger = logging.getLogger(__file__)
logger.setLevel(level=logging.INFO)
formatter = ColoredLoggerFormatter()
formatter.add_to(logger, level=logging.INFO)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HUMAN_BLEND_FILE = os.path.join(SCRIPT_DIR, "HumanKTH283.blend")
BODY_SIM_SERVER_FILE = os.path.join(SCRIPT_DIR, "body_simulator_server.py")
POSE_PROGRAM_FILE = os.path.join(SCRIPT_DIR, "pose_program.jl")

def get_pid(name):
    try:
        return subprocess.check_output(["pidof", name]).strip().decode('utf-8')
    except:
        return None

def run_process(command):    
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
            break

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
            logger.info(f"Directory {samples_base_dir} created.")
        if not os.path.isdir(samples_dir):
            os.mkdir(samples_dir)
            logger.info(f"Subdirectory {samples_dir} created.")
    except:
        pass

    try:
        sample_directory = samples_dir
        if not os.path.isdir(sample_directory):
            os.mkdir(sample_directory)
            logger.info(f"Subdirectory {sample_directory} created.")
        logger.info(f"Subdirectory {sample_directory} set as sample directory.")
        output = subprocess.check_output(
            ["cp", figure_path, f"{sample_directory}/original.png"]
        ).strip().decode('utf-8')
        if output:
            logger.info(output)
    except:
        logger.error("Sample directory could not be created or set.")
        raise RuntimeError("Sample directory could not be created or set.")
    
    blender_command = f"blender {HUMAN_BLEND_FILE} -P {BODY_SIM_SERVER_FILE} --port {port}"
    def run_blender(command, debug_server=False):
        for line in run_process(command):
            if debug_server:
                print(line, end='', flush=True)
            else:
                pass
        return
    blender_thread = Thread(target=run_blender, args=(blender_command, debug_server))
    blender_thread.daemon = True
    blender_thread.start()
    # Wait for blender process to spawn
    time.sleep(0.25)
    # Get PID
    blender_pid = get_pid("blender")
    logger.info(f"Blender process started with PID {blender_pid}")
    # Launches Julia process
    logger.info("Launching Julia program...")
    julia_command = f"julia {POSE_PROGRAM_FILE} {figure_path} {sample_directory} {port}"
    julia_process = subprocess.Popen(julia_command, shell=True)
    julia_process.wait()
    return_code = subprocess.call(
        shlex.split(f"kill -9 {blender_pid}"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    if return_code:
        logger.info("Inference terminated cleanly.")
    blender_thread.join()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="Start inference script")
    parser.add_argument("--figure-path", "-f", type=str, default="examples/small/test.png")
    parser.add_argument("--port", "-p", type=int, default=5000)
    args = parser.parse_args()
    infer(figure_path=args.figure_path, port=args.port)
    