import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class BofListArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class BofListCommand(CommandBase):
    cmd = "bof_list"
    needs_admin = False
    help_cmd = "bof_list"
    description = "List all loaded BOFs"
    version = 1
    author = "@nicholasromanowski"
    argument_class = BofListArguments
    attackmapping = []
    browser_script = None
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

