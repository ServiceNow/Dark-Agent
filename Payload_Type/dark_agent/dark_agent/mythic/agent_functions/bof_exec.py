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
                description="Split arguments to pass to the BOF",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=2
                )]
            ),
            CommandParameter(
                name="bof_args_str",
                type=ParameterType.String,
                description="String arguments to pass to the BOF",
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=3
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        if dictionary_arguments.get("name"):
            self.set_arg("name", dictionary_arguments.get("name"))
        # For backwards compatibility we prioritise "bof_args" split arguments 
        if dictionary_arguments.get("bof_args"):
            bof_args = dictionary_arguments.get("bof_args")
            if dictionary_arguments.get("bof_args_str"):
                bof_args = ' '.join([bof_args, dictionary_arguments.get("bof_args_str")])
            self.set_arg("bof_args", bof_args)
        elif dictionary_arguments.get("bof_args_str"):
            self.set_arg("bof_args_str", dictionary_arguments.get("bof_args_str"))


class BofExecuteCommand(CommandBase):
    cmd = "bof_exec"
    needs_admin = False
    help_cmd = "bof_exec [bof_name] [split_arguments] [string_arguments]"
    description = "Execute a previously loaded BOF with optional arguments, either split or string"
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
        bof_args = taskData.args.get_arg("bof_args") if taskData.args.get_arg("bof_args") else ""
        bof_args_str = taskData.args.get_arg("bof_args_str") if taskData.args.get_arg("bof_args_str") else ""
        display = name
        if bof_args:
            display = f" (split arguments): {name} {bof_args}"
        elif bof_args_str:
            display = f" (string arguments): {name} {bof_args_str}"
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams=display)

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp