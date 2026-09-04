import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class DfArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
      pass

    async def parse_dictionary(self, dictionary_arguments):
      self.add_arg("name", "df")
      self.add_arg("bof_args", "")



class DfCommand(CommandBase):
    cmd = "df"
    needs_admin = False
    help_cmd = "df"
    description = "Display filesystem disk space usage (similar to df -h)"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1082"]
    argument_class = DfArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )
    browser_script = BrowserScript(
        script_name="df",
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