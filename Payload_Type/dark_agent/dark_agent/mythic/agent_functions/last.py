import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class LastArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        self.add_arg("name", "last")
        self.add_arg("bof_args", "")


class LastCommand(CommandBase):
    cmd = "last"
    needs_admin = False
    help_cmd = "last"
    description = "Display login history from wtmp log"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = ["T1033"]
    argument_class = LastArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux]
    )
    browser_script = BrowserScript(
        script_name="last",
        author="@nicholasromanowski",
        for_new_ui=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=""
        )
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp