from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class KrbListCcachesArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class KrbListCcachesCommand(CommandBase):
    cmd = "krb_listccaches"
    needs_admin = False
    help_cmd = "krb_listccaches"
    description = "Enumerate all Kerberos credential caches"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    supported_ui_features = []
    attackmapping = ["T1558"]
    argument_class = KrbListCcachesArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=""
        )
        return response
