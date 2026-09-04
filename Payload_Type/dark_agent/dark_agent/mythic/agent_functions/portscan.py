import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class PortscanArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="host",
                type=ParameterType.String,
                description="Target host to scan",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="ports",
                type=ParameterType.String,
                description="Comma-separated list of ports to scan (e.g., 22,80,443)",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
      pass

    async def parse_dictionary(self, dictionary_arguments):
      host = dictionary_arguments.get("host")
      ports = dictionary_arguments.get("ports")
      self.add_arg("name", "portscan")
      self.add_arg("host", host)
      self.add_arg("ports", ports)
      self.add_arg("bof_args", f"{host} {ports}")



class PortscanCommand(CommandBase):
    cmd = "portscan"
    needs_admin = False
    help_cmd = "portscan <host> <port1,port2,...>"
    description = "Scan specified ports on a target host to check if they're open"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1046"]
    argument_class = PortscanArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
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