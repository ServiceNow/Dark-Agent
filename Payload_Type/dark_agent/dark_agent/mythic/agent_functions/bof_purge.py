from mythic_container.MythicCommandBase import *

class BofPurgeArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        pass


class BofPurgeCommand(CommandBase):
    cmd = "bof_purge"
    needs_admin = False
    help_cmd = "bof_purge"
    description = "Remove all BOFs from memory"
    version = 1
    author = "@nicholasromanowski"
    argument_class = BofPurgeArguments
    attackmapping = []
    browser_script = None
    attributes = CommandAttributes(
        builtin=True
    )

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)

        # Use a friendly message for the user
        if "Successfully purged all BOFs" in response or "purged" in response.lower():
            resp.UserOutput = f"Successfully removed all BOFs from memory\n\n"
        else:
            resp.UserOutput = f"BOF purge response: {response}"

        return resp

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

