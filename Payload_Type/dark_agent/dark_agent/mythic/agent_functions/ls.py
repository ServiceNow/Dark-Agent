from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import re
import string, json
import os

import logging

logging.basicConfig(level=logging.INFO)

class LsArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                type=ParameterType.String,
                description="Path of file or folder on the current system to list",
                parameter_group_info=[ParameterGroupInfo(
                    required=False
                )]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) > 0:
            if self.command_line[0] == '{':
                temp_json = json.loads(self.command_line)
                if "host" in temp_json:
                    self.add_arg("path", temp_json["path"] + "/" + temp_json["file"])
                    self.add_arg("file_browser", True, type=ParameterType.Boolean)
                else:
                    self.add_arg("path", temp_json["path"])
            else:
                self.add_arg("path", self.command_line)
        else:
            self.add_arg("path", ".")

    async def parse_dictionary(self, dictionary):
        logging.info("Parse Dictionary")
        if "host" in dictionary:
            # Then this came from File Browser UI
            logging.info(f"File Browser UI - {dictionary}")
            self.add_arg("path", os.path.join(dictionary["path"], dictionary["file"]))
            self.add_arg("file_browser", type=ParameterType.Boolean, value=True)
        else:
            # Arguments came from command line
            logging.info(f"Command came from CMDLINE - {dictionary}")

            arg_path = dictionary.get("path")
            if arg_path:
                self.add_arg("path", arg_path)
            else:
                self.add_arg("path", ".")

        self.add_arg("file_browser", "true")

        self.load_args_from_dictionary(dictionary)

class LsCommand(CommandBase):
    cmd = "ls"
    needs_admin = False
    help_cmd = "ls [path]"
    description = "List directory contents or file information"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1083"]
    argument_class = LsArguments
    supported_ui_features = ["file_browser:list"]
    browser_script = BrowserScript(
        script_name="ls",
        author="nicholas.romanowski@servicenow.com",
        for_new_ui=True
    )
    attributes = CommandAttributes(
      supported_os=[SupportedOS.Linux, SupportedOS.MacOS],
      builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )

        path = taskData.args.get_arg("path")
        logging.info(f"create_go_tasking - args : {taskData.args}")
        logging.info(f"create_go_tasking - path : {path}")
        response.DisplayParams = path

        if uncmatch := re.match(r"^\\\\(?P<host>[^\\]+)\\(?P<path>.*)$", path):
            taskData.args.add_arg("host", uncmatch.group("host"))
            taskData.args.set_arg("path", uncmatch.group("path"))
        else:
            # Set the host argument to an empty string if it does not exist
            taskData.args.add_arg("host", "")

        if host := taskData.args.get_arg("host"):
            host = host.upper()

            # Resolve 'localhost' and '127.0.0.1' aliases
            if host == "127.0.0.1" or host.lower() == "localhost":
                host = taskData.Callback.Host

            taskData.args.set_arg("host", host)

        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp