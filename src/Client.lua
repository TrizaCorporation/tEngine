local Dependencies = script.Parent.Dependencies
local Promise = require(Dependencies.RbxLuaPromise)
local Signal = require(Dependencies.Signal)
local TNet = require(Dependencies.TNet)
local TNetMain = TNet.new()
local ServiceEventsFolder = script.Parent:WaitForChild("ServiceEvents")
local _warn = warn
local function warn(...)
    _warn("[TGFramework Client]:",...)
end
local Controllers = {}
local TGFrameworkClient = {}
local SignalEvents = {}

local function formatService(controllerName, service)
  local serviceFolder = ServiceEventsFolder:FindFirstChild(service)
  local formattedService = {}
  local Controller = Controllers[controllerName]
  for _, item in serviceFolder.RemoteFunctions:GetChildren() do
    local remoteHandler = SignalEvents[item]
    if not remoteHandler then
      local createdRH = TNetMain:HandleRemoteFunction(item)
      SignalEvents[item] = createdRH
      remoteHandler = createdRH
    end
    if Controller.Middleware then
      if not remoteHandler.Middleware.Inbound and not remoteHandler.Middleware.Outbound then
        remoteHandler.Middleware = {
          Inbound = {},
          Outbound = {}
        }
      end
      if Controller.Middleware.Inbound then
        for _, func in Controller.Middleware.Inbound do
          table.insert(remoteHandler.Middleware.Inbound, func)
        end
      end
      if Controller.Middleware.Outbound then
        for _, func in Controller.Middleware.Outbound do
          table.insert(remoteHandler.Middleware.Outbound, func)
        end
      end
    end
    formattedService[item.Name] = function(...)
      return remoteHandler:Fire(...)
    end
  end
  for _, item in serviceFolder.ClientSignalEvents:GetChildren() do
    local remoteHandler = SignalEvents[item]
    if not remoteHandler then
      local createdRH = item:IsA("RemoteFunction") and TNetMain:HandleRemoteFunction(item) or TNetMain:HandleRemoteEvent(item)
      SignalEvents[item] = createdRH
      remoteHandler = createdRH
    end
    if Controller.Middleware then
      if not remoteHandler.Middleware.Inbound and not remoteHandler.Middleware.Outbound then
        remoteHandler.Middleware = {
          Inbound = {},
          Outbound = {}
        }
      end
      if Controller.Middleware.Inbound then
        for _, func in Controller.Middleware.Inbound do
          table.insert(remoteHandler.Middleware.Inbound, func)
        end
      end
      if Controller.Middleware.Outbound then
        for _, func in Controller.Middleware.Outbound do
          table.insert(remoteHandler.Middleware.Outbound, func)
        end
      end
    end
    formattedService[item.Name] = remoteHandler
  end
  return formattedService
end

function TGFrameworkClient:GetService(service)
  assert(ServiceEventsFolder:FindFirstChild(service), string.format("%s isn't a valid Service.", service))
  local items = debug.traceback():split("GetService")[2]:split(":")[1]:split(".")
  local controllerName = items[#items]
  return formatService(controllerName, service)
end

function TGFrameworkClient:GetController(controller)
  assert(Controllers[controller], string.format("%s isn't a valid Controller.", controller))
  return Controllers[controller]
end

function TGFrameworkClient:CreateController(config)
  assert(config.Name, "A name must be specified for a Controller.")
  assert(not Controllers[config.Name], string.format("A Controller with the name of %s already exists.", config.Name))
  assert(not TGFrameworkClient.Started, "You can't create a controller when TGFramework has already started.")
  local service = config
  Controllers[config.Name] = config
  return service
end

function TGFrameworkClient:AddControllers(directory:Folder, deep:boolean)
  for _, item in if deep then directory:GetDescendants() else directory:GetChildren() do
      if item:IsA("ModuleScript") then
          Promise.try(function()
              require(item)
          end):catch(function(err)
              warn(err)
          end)
      end
  end
end

function TGFrameworkClient:Start()
  return Promise.new(function(resolve, reject, onCancel)
    for _, Controller in Controllers do
      if Controller.Initialize then
        Controller:Initialize()
      end
    end
    self.OnStart:Fire()
    TGFrameworkClient.Started = true
    for _, Controller in Controllers do
      task.spawn(function()
        if Controller.Start then
          Controller:Start()
        end
      end)
    end
    resolve(true)
end)
end

TGFrameworkClient.Started = false
TGFrameworkClient.OnStart = Signal.new()
TGFrameworkClient.Dependencies = Dependencies

return TGFrameworkClient