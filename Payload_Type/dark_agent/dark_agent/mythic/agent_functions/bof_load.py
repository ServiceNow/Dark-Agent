from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json
import base64
import os


class BofLoadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="bof_file",
                display_name="BOF File",
                type=ParameterType.File,
                description="Select a BOF file to upload directly to the agent",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ]
            ),
            CommandParameter(
                name="bof_name",
                display_name="BOF Name",
                description="Name to use when registering the BOF (defaults to filename)",
                type=ParameterType.String,
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        group_name="Default",
                        ui_position=2
                    )
                ]
            )
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise ValueError("Must provide BOF file")
        raise ValueError("Must supply arguments through the modal dialog")

    async def parse_dictionary(self, dictionary_arguments):
        self.load_args_from_dictionary(dictionary_arguments)


class BofLoadCommand(CommandBase):
    cmd = "bof_load"
    needs_admin = False
    help_cmd = "bof_load"
    description = "Load a custom BOF file directly into the agent for use with bof_exec"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    argument_class = BofLoadArguments
    attackmapping = ["T1129"]
    browser_script = None
    attributes = CommandAttributes(
        builtin=True
    )

    async def create_go_tasking(self, taskData: MythicCommandBase.PTTaskMessageAllData) -> MythicCommandBase.PTTaskCreateTaskingMessageResponse:
        response = MythicCommandBase.PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )

        try:
            # Get the uploaded file metadata
            file_search_resp = await SendMythicRPCFileSearch(MythicRPCFileSearchMessage(
                TaskID=taskData.Task.ID,
                AgentFileID=taskData.args.get_arg("bof_file")
            ))

            if not file_search_resp.Success or len(file_search_resp.Files) == 0:
                raise Exception(f"Failed to find uploaded BOF file: {file_search_resp.Error}")

            # Get the filename and determine bof_name if not specified
            file_meta = file_search_resp.Files[0]
            original_filename = file_meta.Filename

            if not taskData.args.get_arg("bof_name"):
                # Extract name from filename (remove .o extension if present)
                bof_name = os.path.splitext(original_filename)[0]
                taskData.args.add_arg("bof_name", bof_name)
            else:
                bof_name = taskData.args.get_arg("bof_name")

            # Get the contents of the file (NOTE: < v0.6.5 use `AgentFileId`, >= v0.6.5 uses `AgentFileID`)
            file_contents_resp = await SendMythicRPCFileGetContent(MythicRPCFileGetContentMessage(
                AgentFileId=taskData.args.get_arg("bof_file")
            ))

            if not file_contents_resp.Success:
                raise Exception(f"Failed to fetch contents of the uploaded BOF file: {file_contents_resp.Error}")

            # Use Mythic's file upload functionality to prepare for chunked download
            file_create_resp = await SendMythicRPCFileCreate(MythicRPCFileCreateMessage(
                TaskID=taskData.Task.ID,
                FileContents=file_contents_resp.Content,
                DeleteAfterFetch=True,
                Comment=f"BOF file: {original_filename}",
                Filename=f"{bof_name}.o"
            ))

            if not file_create_resp.Success:
                raise Exception(f"Failed to register BOF file: {file_create_resp.Error}")

            # Set display parameters
            response.DisplayParams = f"Loading BOF file '{original_filename}' as '{bof_name}'"

            # Set parameters for the agent
            taskData.args.add_arg("command", bof_name)
            taskData.args.add_arg("file_id", file_create_resp.AgentFileId)

        except Exception as e:
            response.Success = False
            response.Error = f"Error preparing BOF: {str(e)}"

        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)

        # Use a friendly message for the user
        if "Successfully loaded BOF" in response:
            bof_name = task.args.get_arg("bof_name")
            resp.UserOutput = f"Successfully loaded BOF '{bof_name}'\n\nYou can execute it with the command: bof_exec {bof_name} [arguments]"
        else:
            resp.UserOutput = f"Error loading BOF: {response}"
            resp.Success = False

        return resp