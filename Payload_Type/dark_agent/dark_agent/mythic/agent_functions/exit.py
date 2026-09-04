from mythic_container.MythicCommandBase import *
import json
from mythic_container.MythicRPC import *

class ExitArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class ExitCommand(CommandBase):
    cmd = "exit"
    needs_admin = False
    help_cmd = "exit"
    description = "Exit your callback"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = []
    supported_ui_features = ["callback_table:exit"]
    argument_class = ExitArguments
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=""
        )
        return response
