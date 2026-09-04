from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json


class UnloadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="name",
                type=ParameterType.String,
                description="Name of the command to unload",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            )
        ]

    async def parse_arguments(self):
      pass

    async def parse_dictionary(self, dictionary_arguments):
        self.load_args_from_dictionary(dictionary_arguments)

class UnloadCommand(CommandBase):
    cmd = "unload"
    needs_admin = False
    help_cmd = "unload [command]"
    description = "Unload a BOF command from the agent"
    version = 1
    author = "@nicholasromanowski"
    argument_class = UnloadArguments
    attackmapping = ["T1129"]
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: MythicCommandBase.PTTaskMessageAllData) -> MythicCommandBase.PTTaskCreateTaskingMessageResponse:
        response = MythicCommandBase.PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )
        command_name = taskData.args.get_arg("name")

        # Set up the task data to pass to the agent
        response.TaskID = taskData.Task.ID
        response.DisplayParams = f"command: {command_name}"

        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)

        # Parse the response from the agent to handle the result
        if "Successfully unloaded BOF" in response:
            command_name = task.args.get_arg("command")
            resp.UserOutput = f"Successfully unloaded {command_name} command"
        else:
            resp.UserOutput = f"Error unloading BOF: {response}"
            resp.Success = False

        return resp