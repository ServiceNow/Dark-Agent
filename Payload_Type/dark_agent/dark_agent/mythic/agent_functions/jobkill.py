from mythic_container.MythicCommandBase import *

class JobkillArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="task_id",
                type=ParameterType.String,
                description="Task ID of the BOF job to kill",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        self.load_args_from_dictionary(dictionary_arguments)


class JobkillCommand(CommandBase):
    cmd = "jobkill"
    needs_admin = False
    help_cmd = "jobkill <task_id>"
    description = "Kill a running BOF job by task ID"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    argument_class = JobkillArguments
    attackmapping = []
    browser_script = None
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams=taskData.args.get_arg("task_id"))
