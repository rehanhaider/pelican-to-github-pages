import os
import sys

sys.path.append(os.curdir)
from pelicanconf import *  # noqa: E402,F403

# A settings file that asks for another folder: the action builds into output/ regardless.
OUTPUT_PATH = "public/"
