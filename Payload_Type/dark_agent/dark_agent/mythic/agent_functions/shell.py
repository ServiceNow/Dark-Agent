from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *

class ShellArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="command",
                type=ParameterType.String,
                description="Shell command to execute",
                parameter_group_info=[ParameterGroupInfo(required=True)]
            )
        ]

    async def parse_arguments(self):
        if len(self.command_line) <= 0:
            raise Exception("Usage: shell [command]")
        self.set_arg("bof_args_str", self.command_line.strip())

    async def parse_dictionary(self, dictionary_arguments):
        command = dictionary_arguments.get("command", "")
        self.add_arg("command", command)
        self.set_arg("bof_args_str", command.strip())

class ShellCommand(CommandBase):
    cmd = "shell"
    needs_admin = False
    help_cmd = "shell [command]"
    description = "Execute shell commands on the target system"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = ["T1059.004"]
    argument_class = ShellArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def opsec_pre(self, taskData: PTTaskMessageAllData) -> PTTTaskOPSECPreTaskMessageResponse:
        # Add immediate visible output for the OPSEC check
        await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
            TaskID=taskData.Task.ID,
            Response=f"🚨 TWO PERSON INTEGRITY REQUIRED 🚨\n\nWaiting for approval from another operator before execution..."
        ))

        response = PTTTaskOPSECPreTaskMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            OpsecPreBlocked=True,
            OpsecPreBypassRole="other_operator",
            OpsecPreMessage=f"SECURITY REVIEW REQUIRED: Shell command execution blocked for OPSEC review.\n\nCommand to execute: {taskData.args.get_arg('bof_args_str')}\n\nThis command will be executed directly on the target system with full privileges. Another operator must review and approve this command before execution."
        )
        return response

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        # Add approval information as output
        approval_info = ""
        if hasattr(taskData.Task, 'OpsecPreBypassed') and taskData.Task.OpsecPreBypassed:
            approval_info = f"\n\n✅ COMMAND APPROVED\n\n"

        await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
            TaskID=taskData.Task.ID,
            Response=approval_info
        ))

        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=taskData.args.get_arg("bof_args_str")
        )

        return response
