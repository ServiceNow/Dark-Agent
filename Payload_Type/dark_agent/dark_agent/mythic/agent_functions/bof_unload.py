from mythic_container.MythicCommandBase import *

class BofUnloadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="name",
                type=ParameterType.String,
                description="Name of the BOF to unload",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        self.load_args_from_dictionary(dictionary_arguments)


class BofUnloadCommand(CommandBase):
    cmd = "bof_unload"
    needs_admin = False
    help_cmd = "bof_unload <name>"
    description = "Unload a BOF from memory"
    version = 1
    author = "@nicholasromanowski"
    argument_class = BofUnloadArguments
    attackmapping = []
    browser_script = None
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams=taskData.args.get_arg("name"))

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)

        # Use a friendly message for the user
        if "Successfully unloaded BOF" in response:
            name = task.args.get_arg("name")
            resp.UserOutput = f"Successfully unloaded BOF '{name}'\n\n"
        else:
            resp.UserOutput = f"Error unloading BOF: {response}"
            resp.Success = False

        return resp