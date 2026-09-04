from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class JobsArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class JobsCommand(CommandBase):
    cmd = "jobs"
    needs_admin = False
    help_cmd = "jobs"
    description = "List active BOF jobs with runtime information"
    version = 1
    author = "@nicholasromanowski"
    argument_class = JobsArguments
    attackmapping = []
    browser_script = BrowserScript(script_name="jobs", author="@nicholasromanowski")
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

