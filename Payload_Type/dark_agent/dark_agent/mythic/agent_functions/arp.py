import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class ArpArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        self.add_arg("name", "arp")
        self.add_arg("bof_args", "")


class ArpCommand(CommandBase):
    cmd = "arp"
    needs_admin = False
    help_cmd = "arp"
    description = "Display the ARP table showing IP to MAC address mappings"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1016"]
    argument_class = ArpArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )
    browser_script = BrowserScript(
        script_name="arp",
        author="nicholas.romanowski@servicenow.com",
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