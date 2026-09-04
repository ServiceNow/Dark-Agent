from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class KillArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="pid",
                type=ParameterType.Number,
                description="Process ID to terminate",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    group_name="Default",
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="signal",
                type=ParameterType.Number,
                description="Signal number to send (default: 15 - SIGTERM, 9 - SIGKILL)",
                default_value=15,
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    group_name="Default",
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
      self.set_arg("bof_args", f"{self.get_arg('pid')} {self.get_arg('signal')}")

    async def parse_dictionary(self, dictionary):
        self.load_args_from_dictionary(dictionary)
        self.set_arg("bof_args", f"{self.get_arg('pid')} {self.get_arg('signal')}")


class KillCommand(CommandBase):
    cmd = "kill"
    needs_admin = False
    help_cmd = "kill <PID> [signal]"
    description = "Terminate a process by PID. Optional signal parameter (default: 15 - SIGTERM)"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    supported_ui_features = ["process_browser:kill"]
    attackmapping = ["T1489"]
    argument_class = KillArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def opsec_pre(self, taskData: PTTaskMessageAllData) -> PTTTaskOPSECPreTaskMessageResponse:
        pid = taskData.args.get_arg("pid")
        signal = taskData.args.get_arg("signal")
        
        # Add immediate visible output for the OPSEC check
        await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
            TaskID=taskData.Task.ID,
            Response=f"🚨 TWO PERSON INTEGRITY REQUIRED 🚨\n\nAttempting to terminate process PID {pid} with signal {signal}.\n\nWaiting for approval from another operator before execution..."
        ))
        
        response = PTTTaskOPSECPreTaskMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            OpsecPreBlocked=True,
            OpsecPreBypassRole="operator",
            OpsecPreMessage=f"SECURITY REVIEW REQUIRED: Process termination blocked for OPSEC review.\n\nPID: {pid}\nSignal: {signal}\n\nKilling processes can trigger security alerts and may impact system stability. Another operator must review and approve this action."
        )
        return response

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        # Add approval information as output
        approval_info = ""
        if hasattr(taskData.Task, 'OpsecPreBypassed') and taskData.Task.OpsecPreBypassed:
            approval_info = f"\n✅ COMMAND APPROVED\n\n"

            await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
                TaskID=taskData.Task.ID,
                Response=approval_info
            ))

        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=taskData.args.get_arg("bof_args")
        )

        return response