#!/usr/bin/env python3
import os
import logging
import cv2
import argparse
from glob import glob
from logger_formatter import ColoredLoggerFormatter
logger = logging.getLogger(__file__)
logger.setLevel(level=logging.INFO)
formatter = ColoredLoggerFormatter()
formatter.add_to(logger, level=logging.INFO)

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

def main(base_dir: str, example: str):
    base_dir = os.path.abspath(os.path.expanduser(base_dir))
    example_dir = os.path.join(base_dir, example)
    if not os.path.isdir(base_dir):
        logger.error("Base directory '%s' not found.", base_dir)
        raise FileNotFoundError(f"Base directory '{base_dir}' not found.")
    if not os.path.isdir(example_dir):
        logger.error("Example directory '%s' not found.", example_dir)
        raise FileNotFoundError(f"Example directory '{example_dir}' not found.")
    
    orig_img_path = os.path.join(example_dir, "original.png")
    images_paths = sorted(
        filter(
            lambda x: not x.endswith("original.png"),
            glob(f"{example_dir}/*.png")
        )
    )
    orig_img = cv2.imread(orig_img_path)
    height, width = orig_img.shape[:2]

    try:
        fourcc = cv2.VideoWriter_fourcc('m', 'p', '4', 'v')
        # fourcc = 0x00000020
    except:
        fourcc = cv2.VideoWriter_fourcc('m', 'p', '4', 'v')
    video_file_path = os.path.join(example_dir, "superposed_video.mp4")
    video_writer = cv2.VideoWriter(video_file_path, fourcc, 30, (width, height))
    
    n = len(images_paths)
    for i, img_path in enumerate(images_paths):
        img = cv2.imread(img_path) 
        frame = cv2.addWeighted(img, 0.5, orig_img, 0.5, 0)
        video_writer.write(frame)
        print(f"\rProcessed images: {i + 1:06d} / {n:06d} [{100.0 * (i + 1) / n:06.2f}%]", end='')
    print(" done.")
    logger.info("Video saved at '%s'.", video_file_path)
    video_writer.release()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="generate_superposed_video")
    parser.add_argument("--base-dir", "-d", type=str, default=os.path.join(SCRIPT_DIR, "samples"))
    parser.add_argument("--example", "-e", type=str, default="test")
    args = parser.parse_args()
    main(args.base_dir, args.example)
