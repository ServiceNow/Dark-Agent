from mythic_container.MythicCommandBase import *


class BofExecuteArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="name",
                type=ParameterType.String,
                description="Name of the BOF to execute",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="bof_args",
                type=ParameterType.String,
                description="Arguments to pass to the BOF",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        self.load_args_from_dictionary(dictionary_arguments)


class BofExecuteCommand(CommandBase):
    cmd = "bof_exec"
    needs_admin = False
    help_cmd = "bof_exec [bof_name] [arguments]"
    description = "Execute a previously loaded BOF with optional arguments"
    version = 1
    author = "@nicholasromanowski"
    argument_class = BofExecuteArguments
    attackmapping = ["T1059"]
    hidden = False  # Make it visible since we'll be using it directly
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        name = taskData.args.get_arg("name")
        bof_args = taskData.args.get_arg("bof_args") or ""
        display = name if not bof_args else f"{name} {bof_args}"
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams=display)

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp