import time
from polymetis import GripperInterface

gripper = GripperInterface(
    ip_address="localhost",
)

# example usages
gripper_state = gripper.get_state()
print("start closing")
gripper.goto(width=0., speed=0.05, force=0.1)
time.sleep(5.0)
print("start opening")
gripper.goto(width=0.2, speed=0.05, force=0.1)
time.sleep(5.0)
print("start grasp")
gripper.grasp(speed=0.05, force=0.1)
time.sleep(5.0)
print("start opening")
gripper.goto(width=0.2, speed=0.05, force=0.1)