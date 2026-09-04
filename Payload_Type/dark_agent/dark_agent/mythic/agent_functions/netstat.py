from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class NetstatArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

class NetstatCommand(CommandBase):
    cmd = "netstat"
    needs_admin = False
    help_cmd = "netstat"
    description = "Display network connection information"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1049"]  # Network Connection Enumeration
    argument_class = NetstatArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux]
    )
    browser_script = BrowserScript(
        script_name="netstat",
        author="nicholas.romanowski@servicenow.com",
        for_new_ui=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

