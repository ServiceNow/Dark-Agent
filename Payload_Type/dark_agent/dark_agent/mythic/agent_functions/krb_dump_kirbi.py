from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class KrbDumpKirbiArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="ccache",
                type=ParameterType.String,
                description="Credential cache name (e.g. API:uuid or FILE:/tmp/krb5cc_0); run krb_listccaches to enumerate",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        ccache = dictionary_arguments.get("ccache") or ""
        self.add_arg("name", "krb_dump_kirbi")
        self.add_arg("ccache", ccache)
        self.add_arg("bof_args_str", ccache)


class KrbDumpKirbiCommand(CommandBase):
    cmd = "krb_dump_kirbi"
    needs_admin = False
    help_cmd = "krb_dump_kirbi <ccache>"
    description = "Dump credentials from a Kerberos credential cache in Kirbi format. Run krb_listccaches first to get cache names."
    version = 1
    author = "@nicholasromanowski"
    supported_ui_features = []
    attackmapping = ["T1558"]
    argument_class = KrbDumpKirbiArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=taskData.args.get_arg("ccache") or ""
        )
        return response
