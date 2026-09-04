from mythic_container.PayloadBuilder import *
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import logging
import os
import tempfile
import asyncio
import base64
import pathlib
import json
import shutil
import traceback
from pathlib import Path


class DarkAgent(PayloadType):
    name = "Dark Agent"
    file_extension = "bin"
    author = "@nicholasromanowski"
    supported_os = [SupportedOS.Linux, SupportedOS.MacOS]
    wrapper = False
    wrapped_payloads = ["dark_loader"]
    note = """An ELF agent written in Crystal."""
    supports_dynamic_loading = True
    c2_profiles = ["http", "httpx"]
    mythic_encrypts = True
    translation_container = None
    check_if_callbacks_alive = True
    build_parameters = [
        BuildParameter(
            name="debug_mode",
            parameter_type=BuildParameterType.Boolean,
            description="Build the agent in debug mode.  Debug mode includes trace messages to stdout when executing.  Don't use this on targets ;-)",
            default_value=False,
            required=False,
            group_name="Debug Options"
        ),
        BuildParameter(
            name="debug_socks",
            parameter_type=BuildParameterType.Boolean,
            description="Build the agent in SOCKS debug mode.  Debug mode includes trace messages to stdout when executing.  Don't use this on targets ;-)",
            default_value=False,
            required=False,
            group_name="Debug Options"
        ),
        BuildParameter(
            name="encryption",
            parameter_type=BuildParameterType.Boolean,
            description="Enable encryption for C2 communications. Recommended for production environments.",
            default_value=True,
            required=False,
            group_name="Security Options"
        ),
        BuildParameter(
            name="ssl_verify",
            parameter_type=BuildParameterType.Boolean,
            description="Enable SSL certificate verification. Disable only for development environments with self-signed certificates.",
            default_value=True,
            required=False,
            group_name="Security Options"
        ),
        BuildParameter(
            name="symmetric_jitter",
            parameter_type=BuildParameterType.Boolean,
            description="Use symmetric jitter (base ± jitter%) instead of traditional positive-only jitter (base + jitter%). Makes beacon timing less predictable.",
            default_value=False,
            required=False,
            group_name="Communication Options"
        ),
        BuildParameter(
            name="realtime",
            parameter_type=BuildParameterType.Boolean,
            description="Realtime mode - immediately send any pending messages without waiting for sleep interval. Significantly reduces latency but increases network traffic.",
            default_value=False,
            required=False,
            group_name="Communication Options"
        ),
        BuildParameter(
            name="chunk_size",
            parameter_type=BuildParameterType.Number,
            description="Size of file transfer chunks in KB. Controls how large each chunk will be for upload/download operations. Default is 512KB.",
            default_value=512,
            required=True,
            group_name="Communication Options"
        ),
    ]

    agent_path = pathlib.Path(".") / "dark_agent" / "mythic"
    agent_code_path = pathlib.Path(".") / "dark_agent" / "agent_code"
    agent_icon_path = agent_path / "dark.svg"
    env = os.environ.copy()


    build_steps = [
        BuildStep(step_name="Gathering Files",      step_description="Copying all files to a temporary location"),
        BuildStep(step_name="Building BOFs",        step_description="Compiling BOF object files"),
        BuildStep(step_name="Configuring Profiles", step_description="Stamping in configuration values"),
        BuildStep(step_name="Compiling",            step_description="Compiling Crystal dark agent executable"),
        BuildStep(step_name="Cleanup",              step_description="Cleaning up the build artifacts")
    ]

    async def handle_http_profile(self, c2, agent_config):
        """Handle standard HTTP profile configuration"""
        logging.info("Processing HTTP profile")
        # Get all parameters from the C2 profile
        c2_params = c2.get_parameters_dict()

        # Ensure core parameters are present
        self.ensure_core_parameters(c2_params)

        # Return configuration with proper profile structure
        return {
            "profile": "http",
            "c2": c2_params,
            "agent": agent_config
        }

    async def handle_httpx_profile(self, c2, agent_config):
        """Handle HTTPX (malleable) profile configuration"""
        logging.info("Processing HTTPX profile")
        # Get all parameters from the C2 profile
        c2_params = c2.get_parameters_dict()

        # Ensure core parameters are present
        self.ensure_core_parameters(c2_params)

        # Process raw_c2_config - this should always be present for httpx
        if "raw_c2_config" in c2_params:
            raw_c2_config_id = c2_params["raw_c2_config"]
            logging.info(f"Found raw_c2_config ID: {raw_c2_config_id}")

            try:
                # Fetch the raw c2 profile content using the file ID
                response = await SendMythicRPCFileGetContent(MythicRPCFileGetContentMessage(AgentFileId=raw_c2_config_id))

                if response.Success:
                    # Parse the content as JSON
                    raw_config_content = response.Content.decode('utf-8')
                    logging.debug(f"Raw config content: {raw_config_content[:100]}...")

                    try:
                        parsed_config = json.loads(raw_config_content)
                        # Replace the ID with the parsed JSON
                        c2_params["raw_c2_config"] = parsed_config

                        # Also extract domains from the parsed config if available
                        domains = []

                        # Check for domain in the name field (often used for domain)
                        if 'name' in parsed_config and '.' in parsed_config['name']:
                            potential_domain = parsed_config['name']
                            # Add protocol if missing
                            if not potential_domain.startswith('http'):
                                potential_domain = 'https://' + potential_domain
                            domains.append(potential_domain)
                            logging.info(f"Found domain in name field: {potential_domain}")

                        # Add any existing domains
                        if "callback_domains" in c2_params and isinstance(c2_params["callback_domains"], list):
                            domains.extend(c2_params["callback_domains"])

                        # Save domains back to params if found
                        if domains:
                            c2_params["callback_domains"] = domains
                            logging.info(f"Using domains: {domains}")

                        logging.info("Successfully parsed raw_c2_config JSON")
                    except json.JSONDecodeError as e:
                        logging.error(f"Failed to parse raw_c2_config as JSON: {e}")
                        raise Exception(f"Error parsing raw_c2_config: {e}")
                else:
                    logging.error(f"Failed to fetch raw_c2_config: {response.Error}")
                    raise Exception(f"Error fetching raw_c2_config: {response.Error}")
            except Exception as e:
                logging.error(f"Error processing raw_c2_config: {str(e)}")
                logging.error(traceback.format_exc())
                raise Exception(f"Error processing raw_c2_config: {str(e)}")
        else:
            logging.error("HTTPX profile missing required raw_c2_config parameter")
            raise Exception("HTTPX profile missing required raw_c2_config parameter")

        # Return configuration with proper profile structure
        return {
            "profile": "httpx",
            "c2": c2_params,
            "agent": agent_config
        }


    def ensure_core_parameters(self, c2_params):
        """Ensure all core parameters required by both HTTP and HTTPX profiles are present"""
        # Check for callback_interval (sleep time)
        if "callback_interval" not in c2_params:
            logging.warning("callback_interval not found in profile, setting default (10)")
            c2_params["callback_interval"] = 10

        # Check for jitter
        if "callback_jitter" not in c2_params:
            logging.warning("callback_jitter not found in profile, setting default (10%)")
            c2_params["callback_jitter"] = 10

        # Check for killdate
        if "killdate" not in c2_params:
            logging.warning("killdate not found in profile, setting to empty string")
            c2_params["killdate"] = ""

    async def build(self) -> BuildResponse:
        # Initialize the response
        resp = BuildResponse(status=BuildStatus.Success)
        logging.basicConfig(level=logging.INFO)

        # Set additional parameters
        DEBUG_MODE = self.get_parameter("debug_mode")
        DEBUG_SOCKS_MODE = self.get_parameter("debug_socks")
        ENCRYPTION = self.get_parameter("encryption")
        SSL_VERIFY = self.get_parameter("ssl_verify")
        SYMMETRIC_JITTER = self.get_parameter("symmetric_jitter")
        REALTIME = self.get_parameter("realtime")
        CHUNK_SIZE = self.get_parameter("chunk_size")
        IS_MACOS = self.selected_os == "macOS"
        tmp = tempfile.TemporaryDirectory(suffix=self.uuid)
        agent_build_path = Path(tmp.name)

        try:
            #################################################################
            #################################################################
            ### Step 1: Gathering files
            ### Copy all files to tmpfile for concurrent builds
            #################################################################
            #################################################################
            try:
                shutil.copytree(self.agent_code_path, agent_build_path, dirs_exist_ok=True)
                logging.debug(f"Copied files to {agent_build_path}")
                step1_status = True
            except Exception:
                step1_status = False

            await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Gathering Files",
                StepStdout="Copying all files to a temporary location",
                StepSuccess=step1_status
            ))

            #################################################################
            #################################################################
            ### Step 2: Building BOFs and storing in Mythic Files API
            #################################################################
            #################################################################
            if IS_MACOS:
                # Cross-compile BOFs for macOS (aarch64) using Zig
                build_cmd = ["./build.sh", "-B"]
                proc = await asyncio.create_subprocess_exec(
                    *build_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=str(agent_build_path)
                )
                stdout, stderr = await proc.communicate()

                if proc.returncode != 0:
                    bof_error = stderr.decode()
                    await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                        PayloadUUID=self.uuid,
                        StepName="Building BOFs",
                        StepStdout=f"Error compiling macOS BOFs: {bof_error}",
                        StepSuccess=False
                    ))
                    raise Exception(f"Failed to build macOS BOFs: {bof_error}")
                else:
                    bofs_dir = agent_build_path / "output" / "bofs" / "macos"
                    bof_files = [f for f in os.listdir(bofs_dir) if f.endswith('.o')]

                    bof_names = []
                    for bof_file in bof_files:
                        bof_path = bofs_dir / bof_file
                        bof_name = os.path.splitext(bof_file)[0]
                        bof_content = open(bof_path, 'rb').read()

                        file_resp = await SendMythicRPCFileCreate(MythicRPCFileCreateMessage(
                            PayloadUUID=self.uuid,
                            FileContents=bof_content,
                            Filename=f"{self.uuid}_{bof_file}",
                            Comment=f"Available BOF (macOS aarch64): {bof_name}"
                        ))

                        if not file_resp.Success:
                            logging.error(f"Failed to store macOS BOF {bof_name}: {file_resp.Error}")
                        else:
                            bof_names.append(bof_name)

                    await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                        PayloadUUID=self.uuid,
                        StepName="Building BOFs",
                        StepStdout=f"Compiled and stored {len(bof_names)} macOS aarch64 BOF files: {', '.join(bof_names)}.\n\nOutput: {stdout.decode()}",
                        StepSuccess=True
                    ))
            else:
                # Build BOFs (Linux only)
                build_cmd = ["./build.sh", "-b"]
                proc = await asyncio.create_subprocess_exec(
                    *build_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=str(agent_build_path)
                )
                stdout, stderr = await proc.communicate()

                if proc.returncode != 0:
                    bof_error = stderr.decode()
                    await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                        PayloadUUID=self.uuid,
                        StepName="Building BOFs",
                        StepStdout=f"Error compiling BOFs: {bof_error}",
                        StepSuccess=False
                    ))
                    raise Exception(f"Failed to build BOFs: {bof_error}")
                else:
                    bofs_dir = agent_build_path / "output" / "bofs"
                    bof_files = [f for f in os.listdir(bofs_dir) if f.endswith('.o')]

                    bof_names = []
                    for bof_file in bof_files:
                        bof_path = bofs_dir / bof_file
                        bof_name = os.path.splitext(bof_file)[0]
                        bof_content = open(bof_path, 'rb').read()
                        logging.info(f"Found bof in {bof_path} ")

                        file_resp = await SendMythicRPCFileCreate(MythicRPCFileCreateMessage(
                            PayloadUUID=self.uuid,
                            FileContents=bof_content,
                            Filename=f"{self.uuid}_{bof_file}",
                            Comment=f"Available BOF: {bof_name}"
                        ))

                        if not file_resp.Success:
                            logging.error(f"Failed to store BOF {bof_name} in Mythic: {file_resp.Error}")
                        else:
                            bof_names.append(bof_name)
                            logging.info(f"Stored BOF {bof_name} in Mythic with ID: {file_resp.AgentFileId}")

                    await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                        PayloadUUID=self.uuid,
                        StepName="Building BOFs",
                        StepStdout=f"Compiled and stored {len(bof_names)} BOF files: {', '.join(bof_names)}.\n\nOutput: {stdout}",
                        StepSuccess=True
                    ))


            #################################################################
            #################################################################
            ### Step 3: Configuration
            #################################################################
            #################################################################
            # Generate configuration from C2 profile
            for c2 in self.c2info:
                profile = c2.get_c2profile()
                profile_type = profile["name"]
                logging.info(f"Profile: {profile_type}")

                # Create base agent configuration
                agent_config = {
                    "uuid": self.uuid,
                    "encryption_enabled": ENCRYPTION,
                    "ssl_verify": SSL_VERIFY,
                    "symmetric_jitter": SYMMETRIC_JITTER,
                    "realtime": REALTIME,
                    "chunk_size": CHUNK_SIZE * 1024  # Convert KB to bytes
                }

                # Process the profile based on its type
                if profile_type == "httpx":
                    config = await self.handle_httpx_profile(c2, agent_config)
                else:
                    # Default to HTTP handling for any other profile (including "http")
                    config = await self.handle_http_profile(c2, agent_config)

                # If encryption is disabled, ensure the c2 profile doesn't have encryption keys
                if not ENCRYPTION:
                    if "AESPSK" in config["c2"]:
                        # Clear the encryption keys but keep the structure
                        config["c2"]["AESPSK"]["value"] = ""
                        config["c2"]["AESPSK"]["enc_key"] = ""
                        config["c2"]["AESPSK"]["dec_key"] = ""

                # Log the generated configuration for debugging
                logging.info(f"Generated configuration for profile type: {config['profile']}")
                logging.info(config)

                # Write configuration directly to the agent build path
                config_file = agent_build_path / "profile.json"

                with open(config_file, "w") as f:
                    json.dump(config, f, indent=2)

                # Set environment variable for build script to use
                self.env["DARK_AGENT_CONFIG_PATH"] = str(config_file)

            await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Configuring Profiles",
                StepStdout="Successfully created dark agent c2 profile json",
                StepSuccess=True
            ))

            #################################################################
            #################################################################
            ### Step 4: Compiling Agent
            #################################################################
            #################################################################
            build_cmd = ["./build.sh"]

            # Detect C2 profile type
            profile_name = "http"
            for c2 in self.c2info:
                c2_profile = c2.get_c2profile()["name"]
                if c2_profile == "httpx":
                    profile_name = c2_profile
                    break

            if IS_MACOS:
                # macOS cross-compile via Crystal + Zig.
                # OpenSSL is statically linked for both platforms with no runtime libssl dependency.
                if DEBUG_MODE:
                    build_cmd.extend(["-p", profile_name, "-M"])
                    output_file = agent_build_path / "output/dark-agent-macos-debug"
                else:
                    build_cmd.extend(["-p", profile_name, "-m"])
                    output_file = agent_build_path / "output/dark-agent-macos"
                binary_type = "Mach-O"
            else:
                # Linux build
                build_cmd.extend(["-p", profile_name])
                if DEBUG_MODE:
                    build_cmd.append("-d")
                    output_file = agent_build_path / "output/dark-agent-debug"
                    binary_type = "ELF"
                elif DEBUG_SOCKS_MODE:
                    build_cmd.append("-S")
                    output_file = agent_build_path / "output/dark-agent-socks-debug"
                    binary_type = "ELF"
                else:
                    build_cmd.append("-r")
                    output_file = agent_build_path / "output/dark-agent"
                    binary_type = "ELF"

            proc = await asyncio.create_subprocess_exec(
                *build_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(agent_build_path),
                env=self.env
            )
            stdout, stderr = await proc.communicate()
            build_output = stdout.decode()
            build_error = f"Error:\n{stderr.decode()}"

            if proc.returncode != 0:
                raise Exception(f"Failed to build agent:\nOutput:\n{build_output}\n\nError:\n{build_error}")

            if os.path.exists(output_file):
                await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                    PayloadUUID=self.uuid,
                    StepName="Compiling",
                    StepStdout=f"Compiled {binary_type} binary in {'DEBUG' if DEBUG_MODE else 'RELEASE'} mode",
                    StepSuccess=True
                ))

                self.file_extension = "bin"
                resp.status = BuildStatus.Success
                resp.payload = open(output_file, 'rb').read()
                encryption_status = "encryption enabled" if ENCRYPTION else "ENCRYPTION DISABLED"
                jitter_mode = "symmetric jitter" if SYMMETRIC_JITTER else "positive-only jitter"
                resp.build_message = (
                    f"Successfully built Dark Agent {binary_type} "
                    f"({'!!!DEBUG!!!' if DEBUG_MODE else 'release'} mode, "
                    f"{encryption_status}, {jitter_mode}, {CHUNK_SIZE}KB chunks)!"
                )
                resp.build_stdout = build_output
            else:
                raise Exception(f"Output file not found: {output_file}\nOutput:\n{build_output}\n\nError:\n{build_error}")

            #################################################################
            #################################################################
            ### Step 5: Cleanup files
            #################################################################
            #################################################################
            await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Cleanup",
                StepStdout="Cleaning up the build artifacts",
                StepSuccess=True
            ))

        # Catch all exceptions here
        except Exception as e:
            # Log the full error details
            logging.error(f"Error building payload:\n{str(e)}")

            # Add to response
            resp.set_status(BuildStatus.Error)
            resp.build_message = "Unknown error while building payload. Check the stderr for this build."
            resp.build_stderr = e
            resp.build_stdout = ""
            resp.payload = b""

            # Update the build step to show failure
            await SendMythicRPCPayloadUpdatebuildStep(MythicRPCPayloadUpdateBuildStepMessage(
                PayloadUUID=self.uuid,
                StepName="Compiling",
                StepStdout=f"Error building dark agent payload!\nError:\n{e}",
                StepSuccess=False
            ))


        return resp

    # Manual check for if a callback is dead based on missing checkin window
    # This should likely be handled on its own, we'll see?
    def check_if_callbacks_alive(self, message):
        return super().check_if_callbacks_alive(message)