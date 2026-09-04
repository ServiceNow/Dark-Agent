from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
from mythic_container.mythic_service import *

class LoadArguments(TaskArguments):
  def __init__(self, command_line, **kwargs):
    super().__init__(command_line, **kwargs)
    self.args = [
      CommandParameter(
        name="name",
        type=ParameterType.ChooseOne,
        description="Name of the BOF command to load",
        dynamic_query_function=self.get_commands,
        parameter_group_info=[ParameterGroupInfo(
            required=True
        )]
      )
    ]

  async def get_commands(self, inputMsg: PTRPCDynamicQueryFunctionMessage) -> PTRPCDynamicQueryFunctionMessageResponse:
    """Returns a list of available commands that aren't already loaded in the agent"""
    response = PTRPCDynamicQueryFunctionMessageResponse(Success=False)
    try:

      # Identify the payload
      payload_resp = await SendMythicRPCPayloadSearch(MythicRPCPayloadSearchMessage(PayloadUUID=inputMsg.PayloadUUID))
      if not payload_resp.Success:
        raise Exception(f"Failed to find payload (for payload type).  Error: {payload_resp.Error}")


      # Use payload name to retrieve a list of all commands
      agent_cmds_resp = await SendMythicRPCCommandSearch(MythicRPCCommandSearchMessage(SearchPayloadTypeName=payload_resp.Payloads[0].PayloadType))
      if not agent_cmds_resp.Success:
        raise Exception(f"Failed to get agent commands.  Error: {agent_cmds_resp.Error}")
      agent_cmd_names = set([cmd.Name for cmd in agent_cmds_resp.Commands])


      # Get a list of commands the current callback has loaded
      search_current_commands = await SendMythicRPCCallbackSearchCommand(MythicRPCCallbackSearchCommandMessage(CallbackID=inputMsg.Callback))
      if not search_current_commands.Success:
        raise Exception(f"Unable to search for exising commands loaded.")
      loaded_cmds = search_current_commands
      loaded_cmd_names = set([cmd.Name for cmd in loaded_cmds.Commands])


      # Subtract the commands and present the list
      diff = set(agent_cmd_names).difference(set(loaded_cmd_names))

      # Return the list of available commands with BOFs
      response.Success = True
      response.Choices = sorted(diff)
      return response

    except Exception as e:
      response.Error = f"Error getting available commands: {str(e)}"
      return response


  async def parse_arguments(self):
    pass

  async def parse_dictionary(self, dictionary_arguments):
    self.load_args_from_dictionary(dictionary_arguments)


class LoadCommand(CommandBase):
  cmd = "load"
  needs_admin = False
  help_cmd = "load [command]"
  description = "Load a BOF'd command into the agent. This command will display available BOFs that can be loaded."
  version = 1
  author = "@nicholasromanowski"
  argument_class = LoadArguments
  attackmapping = ["T1129"]
  browser_script = None
  attributes = CommandAttributes(
    builtin=True,
  )


  async def create_go_tasking(self, taskData: MythicCommandBase.PTTaskMessageAllData) -> MythicCommandBase.PTTaskCreateTaskingMessageResponse:
    response = MythicCommandBase.PTTaskCreateTaskingMessageResponse(
        TaskID=taskData.Task.ID,
        Success=True,
    )
    bof_name = taskData.args.get_arg("name")

    try:

      # Locate the BOF
      bof_search_resp = await SendMythicRPCFileSearch(MythicRPCFileSearchMessage(
        TaskID=taskData.Task.ID,
        Filename=f"{taskData.Payload.UUID}_{bof_name}.o"
      ))

      # Add file id to the agents task
      if bof_search_resp.Success and len(bof_search_resp.Files) > 0:
        taskData.args.add_arg("file_id", bof_search_resp.Files[0].AgentFileId)
        response.DisplayParams = f"{bof_name}"
      else:
        raise Exception(f"Failed to find BOF file for command: {bof_name}")

    except Exception as e:
      raise Exception(f"Faild to to find BOF command.  Error: {str(e)}")

    return response



  async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
      resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
      return resp