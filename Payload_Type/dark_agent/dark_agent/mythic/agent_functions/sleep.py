from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json

class SleepArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="seconds",
                type=ParameterType.Number,
                description="Sleep time in seconds.",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="jitter",
                type=ParameterType.Number,
                description="Jitter percentage in seconds.",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=2
                )]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise ValueError("Must supply sleep seconds")
        parts = self.command_line.split()
        self.add_arg("seconds", int(parts[0]))
        if len(parts) > 1:
            self.add_arg("jitter", int(parts[1]))


    async def parse_dictionary(self, dictionary_arguments):
        seconds = dictionary_arguments.get("seconds")
        jitter = dictionary_arguments.get("jitter", 0)

        if seconds is None:
            raise ValueError("The 'seconds' key is required in the dictionary.")
        try:
            seconds = int(seconds)
        except (ValueError, TypeError):
            raise ValueError("The 'seconds' value must be a non-negative integer.")
        if seconds < 0:
            raise ValueError("The 'seconds' value must be a non-negative integer.")
        try:
            jitter = int(jitter) if jitter is not None else 0
        except (ValueError, TypeError):
            raise ValueError("The 'jitter' value must be a non-negative integer.")

        self.add_arg("seconds", seconds)
        self.add_arg("jitter", jitter)


class SleepCommand(CommandBase):
    cmd = "sleep"
    needs_admin = False
    help_cmd = "sleep <seconds> [jitter_percentage]"
    description = "Change the sleep interval with optional jitter"
    version = 1
    author = "@nicholasromanowski"
    argument_class = SleepArguments
    attackmapping = []
    attributes = CommandAttributes(
        builtin=True
    )

    async def opsec_pre(self, taskData: PTTaskMessageAllData) -> PTTTaskOPSECPreTaskMessageResponse:
        seconds = taskData.args.get_arg("seconds")

        # Check if sleep value is < 10
        if seconds < 10:
            # Special message for sleep 0
            if seconds == 0:
                warning_message = f"🚨 TWO PERSON INTEGRITY REQUIRED 🚨\n\n⚠️ SLEEP 0 DETECTED ⚠️\n\nThis will create continuous beaconing with NO delay!\nHighly recommend using 'sleep 1' instead for interactive operations.\n\nWaiting for approval from another operator before execution..."
            else:
                warning_message = f"🚨 TWO PERSON INTEGRITY REQUIRED 🚨\n\nAggressive sleep interval ({seconds}s) will make the callback very noisy.\n\nWaiting for approval from another operator before execution..."

            # Add immediate visible output for the OPSEC check
            await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
                TaskID=taskData.Task.ID,
                Response=warning_message
            ))

            response = PTTTaskOPSECPreTaskMessageResponse(
                TaskID=taskData.Task.ID,
                Success=True,
                OpsecPreBlocked=True,
                OpsecPreBypassRole="operator",
                OpsecPreMessage=f"SECURITY REVIEW REQUIRED: Aggressive sleep interval blocked for OPSEC review.\n\nSleep value: {seconds} seconds\n\nThis will make the agent beacon very aggressively and may be detected. Another operator must review and approve this sleep interval."
            )
        else:
            response = PTTTaskOPSECPreTaskMessageResponse(
                TaskID=taskData.Task.ID,
                Success=True,
                OpsecPreBlocked=False
            )

        return response

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        # Add approval information as output for aggressive sleep values
        seconds = taskData.args.get_arg("seconds")
        approval_info = ""

        if seconds < 10 and hasattr(taskData.Task, 'OpsecPreBypassed') and taskData.Task.OpsecPreBypassed:
            approval_info = f"\n✅ COMMAND APPROVED\n"

            await SendMythicRPCResponseCreate(MythicRPCResponseCreateMessage(
                TaskID=taskData.Task.ID,
                Response=approval_info
            ))

        jitter = taskData.args.get_arg("jitter") or 0
        display = f"{seconds}s" if not jitter else f"{seconds}s jitter {jitter}%"
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=display,
        )
        return response
