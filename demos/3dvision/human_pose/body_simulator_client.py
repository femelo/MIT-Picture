# Human Program Simulator
import logging
import socket
import json
import numpy as np
from logger_formatter import ColoredLoggerFormatter
logger = logging.getLogger(__file__)
logger.setLevel(level=logging.INFO)
formatter = ColoredLoggerFormatter()
formatter.add_to(logger, level=logging.INFO)

class BodySimulatorClient:
    """Body Simulator Client class."""
    def __init__(self, port):
        self.HOST = 'localhost'    	  # The remote host
        self.PORT = port  # 50014        # The same port as used by the server

    def execute(self, data):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((self.HOST, self.PORT))
        self.sock.send(data.encode('utf-8'))
        recdata = self.sock.recv(10240)
        recdata = recdata.decode("utf-8")
        recdata = json.loads(recdata)
        self.sock.close()
        return recdata

    def test(self):
        if True:
            data = json.dumps({'cmd': 'getBoneNames'})
            bones = self.execute(data)
            logger.info('getBoneNames: %s', bones)

        if True:
            data = json.dumps({'cmd': 'captureViewport'})
            ret = self.execute(data)
            logger.info('captureViewport: %s', ret)

        if True:
            data = json.dumps(
                {'cmd': 'getBoneRotationEuler', 'name': 'MASTER', 'id': 0})
            ret = self.execute(data)
            logger.info("Received data 1: %s", ret)

            boneid = bones.index('hip')
            data = json.dumps({'cmd': 'getBoneRotationEuler',
                              'name': 'hip', 'id': boneid})
            rot = self.execute(data)
            rot = np.array(rot)
            logger.info("Received data 2: %s", rot)

            boneid = bones.index('LEGS')
            data = json.dumps(
                {'cmd': 'setBoneLocation', 'name': 'LEGS', 'id': boneid, 'M': [0, 1, 0]})
            ret = self.execute(data)
            logger.info("Received data 3: %s", rot)


if __name__ == "__main__":
    simclient = BodySimulatorClient(5000)
    simclient.test()
