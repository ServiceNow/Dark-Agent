import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class NslookupArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="hostnames",
                type=ParameterType.String,
                description="Comma-separated list of hostnames to lookup (e.g., google.com,github.com)",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="nameserver",
                type=ParameterType.String,
                description="Optional nameserver to use for DNS queries",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
      pass

    async def parse_dictionary(self, dictionary_arguments):
      hostnames = dictionary_arguments.get("hostnames")
      nameserver = dictionary_arguments.get("nameserver")
      self.add_arg("name", "nslookup")
      self.add_arg("hostnames", hostnames)
      self.add_arg("nameserver", nameserver)
      
      if nameserver:
          self.add_arg("bof_args", f"{hostnames} {nameserver}")
      else:
          self.add_arg("bof_args", hostnames)



class NslookupCommand(CommandBase):
    cmd = "nslookup"
    needs_admin = False
    help_cmd = "nslookup <hostname1>,<hostname2> [nameserver]"
    description = "Perform DNS lookups on comma-separated hostnames with optional nameserver"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1016"]
    argument_class = NslookupArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )
    browser_script = BrowserScript(
        script_name="nslookup",
        author="nicholas.romanowski@servicenow.com",
        for_new_ui=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
      response = PTTaskCreateTaskingMessageResponse(
          TaskID=taskData.Task.ID,
          Success=True,
          DisplayParams=taskData.args.get_arg("bof_args")
      )
      return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp