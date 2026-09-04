from mythic_container.MythicCommandBase import *
import json
from mythic_container.MythicRPC import *

class SocksArguments(TaskArguments):

    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="port",
                cli_name="Port",
                display_name="Port",
                type=ParameterType.Number,
                description="Port to start the socks server on.",
                parameter_group_info=[ParameterGroupInfo(
                    ui_position=0,
                    required=True
                )]
            ),
            CommandParameter(
                name="action",
                cli_name="Action",
                display_name="Action",
                type=ParameterType.ChooseOne,
                choices=["start", "stop"],
                default_value="start",
                description="Start or stop proxy server for this port.",
                parameter_group_info=[ParameterGroupInfo(
                    ui_position=1,
                    required=False
                )],
            )
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise Exception("Must be passed a port on the command line. Usage: socks [port] {start|stop}")
        try:
            # First try to parse as JSON (UI interface)
            self.load_args_from_json_string(self.command_line)
        except:
            # Parse command line format: "socks 7005 start" or just "socks 7005" (defaults to start)
            parts = self.command_line.lower().strip().split()

            # Handle port number
            if len(parts) >= 1:
                try:
                    self.add_arg("port", int(parts[0]))
                except ValueError:
                    raise Exception(f"Invalid port number: {parts[0]}. Must be an integer.")

            # Handle action (start/stop)
            if len(parts) >= 2:
                action = parts[1]
                if action not in ["start", "stop"]:
                    raise Exception(f"Invalid action: {action}. Must be 'start' or 'stop'.")
                self.add_arg("action", action)
            else:
                # Default to start if no action specified
                self.add_arg("action", "start")


class SocksCommand(CommandBase):
    cmd = "socks"
    needs_admin = False
    help_cmd = "socks [port number] {start|stop}"
    description = "Enable SOCKS5 compliant proxy to send data to the target network."
    version = 2
    script_only = True
    author = "nicholas.romanowski@servicenow.com"
    argument_class = SocksArguments
    attackmapping = ["T1090"]
    attributes=CommandAttributes(
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS],
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        if taskData.args.get_arg("action") == "start":
            resp = await SendMythicRPCProxyStartCommand(MythicRPCProxyStartMessage(
                TaskID=taskData.Task.ID,
                PortType="socks",
                LocalPort=taskData.args.get_arg("port")
            ))

            if not resp.Success:
                response.TaskStatus = MythicStatus.Error
                response.Stderr = resp.Error
                await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
                    TaskID=taskData.Task.ID,
                    Response=resp.Error.encode()
                ))
            else:
                response.DisplayParams = "Started SOCKS5 server on port {}".format(taskData.args.get_arg("port"))
                response.TaskStatus = MythicStatus.Success
                response.Completed = True
        else:
            resp = await SendMythicRPCProxyStopCommand(MythicRPCProxyStopMessage(
                TaskID=taskData.Task.ID,
                PortType="socks",
                Port=taskData.args.get_arg("port")
            ))

            if not resp.Success:
                response.TaskStatus = MythicStatus.Error
                response.Stderr = resp.Error
                await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
                    TaskID=taskData.Task.ID,
                    Response=resp.Error.encode()
                ))
            else:
                response.DisplayParams = "Stopped SOCKS5 server on port {}".format(taskData.args.get_arg("port"))
                response.TaskStatus = MythicStatus.Success
                response.Completed = True
        return response


    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp