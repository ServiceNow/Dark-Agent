from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json


class TimestompArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="target_file",
                type=ParameterType.String,
                description="File to modify timestamps for",
                parameter_group_info=[
                    ParameterGroupInfo(required=True, ui_position=1, group_name="Reference File"),
                    ParameterGroupInfo(required=True, ui_position=1, group_name="Specific Time")
                ]
            ),
            CommandParameter(
                name="source_type",
                type=ParameterType.ChooseOne,
                description="Source for timestamps",
                choices=["reference_file", "specific_time"],
                parameter_group_info=[
                    ParameterGroupInfo(required=True, ui_position=2, group_name="Reference File"),
                    ParameterGroupInfo(required=True, ui_position=2, group_name="Specific Time")
                ]
            ),
            CommandParameter(
                name="reference_file",
                type=ParameterType.String,
                description="Reference file to copy timestamps from",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=3,
                    group_name="Reference File"
                )]
            ),
            CommandParameter(
                name="timestamp",
                type=ParameterType.String,
                description="Specific timestamp (format: YYYY-MM-DD HH:MM:SS)",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=3,
                    group_name="Specific Time"
                )]
            )
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise ValueError("No arguments given")

        parts = self.command_line.split(maxsplit=2)

        if len(parts) < 2:
            raise ValueError("Not enough arguments")

        self.add_arg("target_file", parts[0])

        # Check if the second argument starts with @
        if parts[1].startswith("@"):
            self.add_arg("source_type", "reference_file")
            self.add_arg("reference_file", parts[1][1:])  # Remove the @ symbol
        else:
            self.add_arg("source_type", "specific_time")
            self.add_arg("timestamp", parts[1])


class TimestompCommand(CommandBase):
    cmd = "timestomp"
    needs_admin = False
    help_cmd = "timestomp <target_file> <@reference_file|timestamp>"
    description = "Modify file timestamps that a specified timestamp or a @reference_file"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    argument_class = TimestompArguments
    attackmapping = ["T1070.006"]
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: MythicCommandBase.PTTaskMessageAllData) -> MythicCommandBase.PTTaskCreateTaskingMessageResponse:
        response = MythicCommandBase.PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )

        # Build the arguments for the BOF
        source_type = taskData.args.get_arg("source_type")
        target_file = taskData.args.get_arg("target_file")

        if source_type == "reference_file":
            reference_file = taskData.args.get_arg("reference_file")
            response.DisplayParams = f"target: {target_file}, reference: {reference_file}"

            # Set parameters for the agent - will call bof_exec internally
            response.CommandParameters = json.dumps({
                "bof_name": "timestomp",
                "arguments": f"{target_file} @{reference_file}"
            })
        else:
            timestamp = taskData.args.get_arg("timestamp")
            response.DisplayParams = f"target: {target_file}, time: {timestamp}"

            # Set parameters for the agent - will call bof_exec internally
            response.CommandParameters = json.dumps({
                "bof_name": "timestomp",
                "arguments": f"{target_file} {timestamp}"
            })

        return response