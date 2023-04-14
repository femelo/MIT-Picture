# Human Program Simulator
import bpy
import os
import socket
import json
import sys
import math
import time
import sys
import logging
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

if sys.platform == 'win32':
    os.system("")

class ColoredLoggerFormatter(Formatter):
    """Logger custom formatting class"""
    cyan = '\x1b[36m'
    green = '\x1b[32m'
    yellow = '\x1b[36m'
    light_red = '\x1b[91m'
    red = '\x1b[31m'
    reset = '\x1b[39m'
    format1 = "[%(levelname)-8s] %(message)s"
    format2 = "[%(levelname)-8s] [%(filename)-25s: %(lineno)04d] %(message)s"
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

logger = logging.getLogger(__file__)
logger.setLevel(level=INFO)
formatter = ColoredLoggerFormatter()
formatter.add_to(logger, level=INFO)

class BodySimulatorServer:
    """Simulator server class."""
    def __init__(self, port=5000):
        self.rootdir = os.path.join('samples', 'tmp' + str(time.time()))
        self.rig = bpy.data.objects['rig']
        self.pose = self.rig.pose
        logger.info("Initial pose: %s", self.pose)
        self.bones = self.pose.bones
        self.capture_cnt = 0
        self.HOST = '127.0.0.1'
        self.PORT = port
        logger.info("Listening to port %s", self.PORT)
        self.CONNECTION_LIST = []
        self.connect()

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((self.HOST, self.PORT))
        self.sock.listen(5)
        # self.CONNECTION_LIST.append(self.sock)

    def getBoneNames(self):
        return [s.name for s in self.bones]

    def getBoneRotationEuler(self, name, id):
        # if self.bones[id].name != name:
        # logger.error('Bone name does not match name in Blender!')
        # raise
        return list(self.bones[id].rotation_euler)

    def setBoneRotationEuler(self, name, _id, M):
        # logger.info('setBoneRotationEuler: %s', M)
        #   if self.bones[_id].name != name:
        #       logger.error('Bone name does not match name in Blender!')
        #       return -1
        self.bones[_id].rotation_mode = 'XYZ'

        if M[0] != 'None' and abs(M[0] - self.bones[_id].rotation_euler[0]) > 0.02:
            self.bones[_id].rotation_euler[0] = math.radians(M[0])
        if M[1] != 'None' and abs(M[1] - self.bones[_id].rotation_euler[1]) > 0.02:
            self.bones[_id].rotation_euler[1] = math.radians(M[1])
        if M[2] != 'None' and abs(M[2] - self.bones[_id].rotation_euler[2]) > 0.02:
            self.bones[_id].rotation_euler[2] = math.radians(M[2])

        # store_X = self.bones[_id].rotation_euler[0]
        # store_Y = self.bones[_id].rotation_euler[1]
        # store_Z = self.bones[_id].rotation_euler[2]

        # self.bones[_id].rotation_euler.rotate_axis('X',-store_X)
        # self.bones[_id].rotation_euler.rotate_axis('Y',-store_Y)
        # self.bones[_id].rotation_euler.rotate_axis('Z',-store_Z)

        # if M[0] != 'None':
        # store_X = math.radians(M[0])
        # if M[1] != 'None':
        # store_Y = math.radians(M[1])
        # if M[2] != 'None':
        # store_Z = math.radians(M[2])

        # self.bones[_id].rotation_euler.rotate_axis('X',store_X)
        # self.bones[_id].rotation_euler.rotate_axis('Y',store_Y)
        # self.bones[_id].rotation_euler.rotate_axis('Z',store_Z)

        fname = 1  # self.captureViewport()
        # logger.info('[END] setBoneRotationEuler: %s', M)
        return fname

    def setBoneLocation(self, name, id, M):
        # logger.info('setBoneLocation: %s', M)
        # if self.bones[id].name != name:
        #   logger.error('Bone name does not match name in Blender!')
        #   return -1
        if M[0] != 'None' and M[0] != self.bones[id].location[0]:
            self.bones[id].location[0] = M[0]
        if M[1] != 'None' and M[1] != self.bones[id].location[1]:
            self.bones[id].location[1] = M[1]
        if M[2] != 'None' and M[2] != self.bones[id].location[2]:
            self.bones[id].location[2] = M[2]
        fname = 1  # self.captureViewport()
        return fname

    def setGlobalAffine(self, name, id, M):
        # logger.info('setGlobalAffine: %s', M)
        if M[0] != 'None' and M[0] != self.rig.scale[0]:
            self.rig.scale = (M[0], M[0], M[0])

        if M[1] != 'None' and abs(M[1] - self.bones[id].rotation_euler[0]) > 0.02:
            self.rig.rotation_euler[0] = math.radians(M[1])
        if M[2] != 'None' and abs(M[2] - self.bones[id].rotation_euler[1]) > 0.02:
            self.rig.rotation_euler[1] = math.radians(M[2])
        if M[3] != 'None' and abs(M[3] - self.bones[id].rotation_euler[2]) > 0.02:
            self.rig.rotation_euler[2] = math.radians(M[3])

        # store_X = self.rig.rotation_euler[0]
        # store_Y = self.rig.rotation_euler[1]
        # store_Z = self.rig.rotation_euler[2]

        # self.rig.rotation_euler.rotate_axis('X',-store_X)
        # self.rig.rotation_euler.rotate_axis('Y',-store_Y)
        # self.rig.rotation_euler.rotate_axis('Z',-store_Z)

        # if M[1] != 'None':
        # store_X = math.radians(M[1])
        # if M[2] != 'None':
        # store_Y = math.radians(M[2])
        # if M[3] != 'None':
        # store_Z = math.radians(M[3])

        # self.rig.rotation_euler.rotate_axis('X',store_X)
        # self.rig.rotation_euler.rotate_axis('Y',store_Y)
        # self.rig.rotation_euler.rotate_axis('Z',store_Z)

        if M[4] != 'None' and M[4] != self.bones[id].location[0]:
            self.rig.location[0] = M[4]
        if M[5] != 'None' and M[5] != self.bones[id].location[1]:
            self.rig.location[1] = M[5]
        if M[6] != 'None' and M[6] != self.bones[id].location[2]:
            self.rig.location[2] = M[6]

        fname = 1  # self.captureViewport()
        return fname

    def captureViewport(self):
        # bpy.data.scenes["Scene"].use_nodes=True
        file_path = os.path.join(
            self.rootdir,
            f"{self.capture_cnt:06d}.png"
        ) # 'rendered.png'
        logger.info("Rendering saved to: %s", file_path)
        bpy.context.scene.render.filepath = file_path
        bpy.ops.render.opengl(write_still=True)
        self.capture_cnt += 1
        return bpy.context.scene.render.filepath

    def captureViewport_Texture(self):
        bpy.data.scenes["Scene"].use_nodes = False
        bpy.context.scene.render.filepath = os.path.join(
            self.rootdir,
            f"{self.capture_cnt:06d}_texture.png"
        )
        bpy.ops.render.render(write_still=True)
        self.capture_cnt += 1
        return bpy.context.scene.render.filepath

    def setRootDir(self, rootdir):
        self.rootdir = rootdir

    def process(self, data):
        logger.info("Data to process: %s", data)
        data = json.loads(data)
        cmd = data['cmd']

        # replacing for matlab -- should fix this later
        if 'M' in data:
            if isinstance(data['M'], list):
                for i in range(len(data['M'])):
                    if data['M'][i] == -999:
                        data['M'][i] = 'None'
            else:
                logger.error('Error in processing!')
                sys.exit()

        ret = None
        if cmd == 'getBoneNames':
            ret = self.getBoneNames()
        if cmd == 'setBoneRotationEuler':
            ret = self.setBoneRotationEuler(
                data['name'], data['id'], data['M'])
        if cmd == 'getBoneRotationEuler':
            ret = self.getBoneRotationEuler(data['name'], data['id'])
        if cmd == 'setBoneLocation':
            ret = self.setBoneLocation(data['name'], data['id'], data['M'])
        if cmd == 'captureViewport':
            ret = self.captureViewport()
        if cmd == 'captureViewport_Texture':
            ret = self.captureViewport_Texture()
        if cmd == 'setGlobalAffine':
            ret = self.setGlobalAffine(data['name'], data['id'], data['M'])
        if cmd == 'setRootDir':
            ret = self.setRootDir(data['rootdir'])
        return json.dumps(ret)

    def run(self):
        # for i in range(100000):
        while True:
            sockfd, addr = self.sock.accept()
            logger.info("Client (%s, %s) connected", *addr)

            data = sockfd.recv(10240)
            data = data.decode("utf-8")
            logger.info("Data received: %s", data)
            if len(data) > 0 and data != None:
                ret = self.process(data)
                # first send number of bytes
                # logger.info("Number of bytes: %s", str(sys.getsizeof(ret)).encode('utf-8'))
                # sockfd.send(str(sys.getsizeof(ret)).encode('utf-8'))
                # recv OK
                # sockfd.recv(24)
                # then send actual data

                # REQUIRED
                sockfd.send(ret.encode('utf-8'))
            sockfd.close()


if __name__ == "__main__":
    port = 5000
    if "--port" in sys.argv:
        i = sys.argv.index("--port")
        if len(sys.argv) > i + 1:
            port = int(sys.argv[i + 1])
    simserver = BodySimulatorServer(port=port)
    simserver.run()
