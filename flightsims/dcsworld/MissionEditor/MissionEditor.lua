__DO_NOT_ERASE_DEBRIEF_LOG__ = false;

NEW_GUI = true

-- добавлять коды команд в тултип для команды
OPTIONS_ADD_COMMAND_CODES_TO_TOOLTIP = false

if NEW_GUI then
  guiBindPath = './dxgui/bind/?.lua;' .. 
                './dxgui/old_loader/?.lua;' .. 
                './dxgui/ThemeConverter/?.lua;' ..
                './dxgui/skins/skinME/?.lua;' .. 
                './dxgui/skins/common/?.lua;'
end

package.path = 
       ''
    .. guiBindPath
    .. '.\\MissionEditor\\?.lua;'
    .. '.\\MissionEditor\\themes\\main\\?.lua;'
    .. '.\\MissionEditor\\modules\\?.lua;'	
    .. '.\\Scripts\\?.lua;'
    .. '.\\LuaSerializer\\?.lua;'
    .. '.\\LuaSocket\\?.lua;'
	.. '.\\Scripts\\UI\\?.lua;'    -- для debriefing

    
-- загружаем новый скин
local function loadSkin()
  skinPath = './dxgui/skins/skinME/'
  dofile(skinPath .. 'skin.lua')
end

hookLog 				= {};    
START_PARAMS.command    = 'quit';
main_w                  = 1024
main_h                  = 768
defaultReturnScreen     = 'mainmenu'
tempMissionName         = 'tempMission.miz'
trackFileName           = 'LastMissionTrack.trk';
watchTrackFileName      = '_LastMissionTrack.trk';
mainPath				= 'MissionEditor/'
themesPath          = mainPath   .. 'themes/'
fontsPath           = themesPath .. 'fonts/'
imagesPath          = themesPath .. 'main/images/'

if 'LOFAC' == START_PARAMS.returnScreen  then
    LOFAC = true;
else
    LOFAC = false;
end;



--__TYPE_ME__ = START_PARAMS.typeME
--__HIP__ = true; --#TMP
--__HIP__ = false; --#TMP

DEBUG = true

function hookFcn(event, lineNumber)
    local functionFilter = {
        ['unpack'] = true,
        ['xpcall'] = true,
        ['member'] = true,
        ['type'] = true,
        ['time'] = true,
        ['date'] = true,
        ['remove'] = true,
        ['isVisible'] = true,
        ['setText'] = true,
        ['(for generator)'] = true,
        ['old_pairs'] = true,
    }
    local info = debug.getinfo(2);
    local fun = info.name or '';
    if string.find(info.short_src, 'me_traceback') then
        return;
    end;
    if functionFilter[fun] then
        return;
    end;
    local counter = 3;
    local tabString = '';
    local _info = {};
    while _info ~= nil do        
        tabString = tabString .. '  ';
        _info = debug.getinfo(counter);
        counter = counter + 1;
    end;
    print(tabString .. info.short_src .. ' in line ' .. info.currentline .. ' in func: ' .. fun)
    -- local str = tabString .. info.short_src .. ' in line ' .. info.currentline .. ' in func: ' .. fun;
    -- local hookRec = {
        -- info = tabString .. fun .. ' - ' .. info.short_src .. ' in line ' .. info.currentline,
        -- short_src = tabString .. info.short_src,
        -- currentline = info.currentline,
        -- fun = fun,
        -- time = os.clock(),
    -- };
    --table.insert(hookLog, hookRec);
    --table.insert(hookLog, str);
end; 
--debug.sethook ( hookFcn, 'c' );

--traceback = require('me_traceback')
--profiler = require("profiler");
-- profiler.start('Profiler.txt');

local textutil = require('textutil')

local old_sort = table.sort;
table.sort = function(tbl, fun)
    if (type(tbl[1]) == 'string') and (fun == nil) then
        old_sort(tbl, function(op1, op2) return textutil.CompareUtf8(op1, op2); end)
    else
        old_sort(tbl, fun)
    end;
end;

 -- поиск вывода nil
-- local old_print = print
-- local new_print
-- print = function(...)
	-- print = old_print
	-- for i = 1, arg.n  do
		-- if (arg[i]==nil) then			
			-- local t  = debug.traceback();
			-- local ind = string.find(t, '\n');
			-- ind = string.find(t, '\n', ind+1);
			-- t = string.sub(t,ind)
			-- print(t)			
			-- print("NILLLLLLLLLLLLLL");			
		-- end
	-- end
	
	-- for k=1, arg.n do
		-- print("arg[i]=",k, arg[k])
	-- end
	-- print = new_print
-- end
-- new_print = print


os.execute('del /F /Q *.tmp >nul 2>nul');
os.execute('cls');

lfs = require('lfs')  -- Lua File System
local T = require('tools')

absolutPath			= lfs.currentdir()
simPath	 			= './' -- путь к корневой папке симулятора
missionDir			= lfs.writedir() .. 'Missions/'
moviesDir			= lfs.writedir() .. 'Movies/'
userDataDir			= lfs.writedir() .. 'MissionEditor/'
tempDataDir			= lfs.tempdir()
configPath 			= lfs.writedir() .. 'Config/'
tempMissionPath 	= tempDataDir .. 'Mission/' -- путь к временной папке ресурсов миссий
tempCampaignPath 	= tempDataDir .. 'Campaign/' -- путь к временной папке ресурсов миссий
dialogsDir 			= mainPath   .. 'modules/dialogs/' -- путь к диалогам
userFiles 			= T.safeDoFileWithRequire(simPath .. 'Scripts/UserFiles.lua')
--configHelper 		= T.safeDoFileWithRequire(simPath .. 'Scripts/ConfigHelper.lua')

imageSearchPath = {
--    imagesPath .. 'COMMON/',
    imagesPath
    };
	
SEARCHPATH = {};
    

--__KA50_VERSION__ = true
--__HUMAN_PLANE__ = true
--__FINAL_VERSION__ = true
--__A10C_VERSION__ = true

--__BETA_VERSION__ = true

--print("*****__FINAL_VERSION__=",__FINAL_VERSION__)
--print("*****__A10C_VERSION__=",__A10C_VERSION__)

if (LOFAC == true) then
		imageSearchPath[2] = imagesPath .. 'lofac/'
else        
  --  if __KA50_VERSION__ then
  --      table.insert(imageSearchPath, 1, imagesPath .. 'Ka50/');
  --  end
end    

function getSearchPath()
    return SEARCHPATH
end;

local function loadInternationalization()
  i18 = require('i18n')

  i18.setLocale(simPath .. "l10n")
  i18.gettext.add_package("input")
  i18.gettext.add_package("inputEvents")
  i18.gettext.add_package("payloads")

 -- print("-----------------------------1")
  -- ЗАГРУЗКА ПЕРЕВОДОВ ИЗ ПЛАГИНОВ 
	for dir in lfs.dir("Mods/aircrafts") do
		local fullNameDir  = 'Mods/aircrafts' .. '/' .. dir
		local d = lfs.attributes(fullNameDir)
		if (d and (d.mode == 'directory') and (dir ~= '.') and (dir~='..')) then
			local ldir = lfs.attributes(fullNameDir.. '/l10n')
			if (ldir and (ldir.mode == 'directory')) then
				i18.gettext.add_package("messages", simPath .. '/' .. fullNameDir.. '/'.. "l10n")
			end
		end
	end
  --print("-----------------------------2")
end

loadInternationalization() -- НЕ ПЕРЕНОСИТЬ !

-- fall back to default locale
os.setlocale("C")
os.setlocale("","time")

local function loadTheme()
  -- загрузка темы для GUI
  -- путь к папке с темами GUI
  themesPath = mainPath .. 'themes/'
  
  dofile(themesPath..'main/Theme.lua')
end

MAX_TEXTURE_SIZE = 2048

local function loadDatabase()
  me_db = require('me_db_api')
  me_db.create() -- чтение и обработка БД редактора
  
end

local function loadOptions()
  panel_options = require('me_options')
  panel_options.loadOptions()
end

local function getScreenParams()
  local width = panel_options.vdata.graphics.width.__value__
  local height = panel_options.vdata.graphics.height.__value__
  local fullscreen = panel_options.vdata.graphics.fullScreen.__value__
  
  local screen_w, screen_h = Gui.GetCurrentVideoMode()
  
  if screen_w <= width or screen_h <= height then
      fullscreen = true
  end  
  
  if fullscreen then 
      width = screen_w
      height = screen_h
  end
  
  return width, height, fullscreen
end

local function createWaitScreen()
  -- Заставка с прогресс-баром
  wait_screen = require('me_wait_screen')
  wait_screen.create(0, 0, main_w, main_h)
end

function getLocalizedFilename(fileName)
  local result
  
  if LOFAC then
    local start = i18n.findBack(fileName, '\\/')
    
    if 0 ~= start then
      local path = string.sub(fileName, 1, start)
      local newname = path .. "lofac" .. string.sub(fileName, start)
      
      result = i18n.getLocalizedFileName(newname)
    end
  end
  
  if not result then
    result = i18n.getLocalizedFileName(fileName)
  end
  
  if not result then
      result = fileName
  end  
  
  return result
end

local function createGUI()
  Gui = require('dxgui')
  
  -- пути поиска картинок должны быть установлены до вызова Gui.Create()
  Gui.FindImageFile = getLocalizedFilename
  
  local width, height, fullscreen = getScreenParams()
  
  if NEW_GUI then
    -- создаем окно приложения
    
    Gui.CreateWindow(width, height, fullscreen)
    Gui.SetWaitCursor(true)	
    -- инициализация рендера должна быть выполнена до вызова Gui.Create()
    dxgui.CreateEdgeRender('dxgui_edge_render.dll', './MissionEditor/gui.fx', './Config/missionEditor.cfg')
    Gui.CreateGUI('./dxgui/skins/skinME/skin.lua')
    
    if (LOFAC) then
        local locale =i18n.getLocale()
        if locale == 'ru' then 
			Gui.SetBackground('./MissionEditor/themes/main/images/lofac/loading-window_RU.png')
            Gui.SetWindowText('СПО-НОПП')
        else
            Gui.SetBackground('./MissionEditor/themes/main/images/lofac/loading-window.png')
            Gui.SetWindowText('JFT')
        end
    else    
		Gui.SetBackground('./MissionEditor/themes/main/images/loading-window.png')
		Gui.SetWindowText('Digital Combat Simulator')
    end
    
    Gui.Redraw()
  else
    Gui.Create(width, height, fullscreen) 
  end
	if LOFAC then
		Gui.SetIcon(mainPath..'../FUI_FAC/LOFAC.ico')
 --   elseif __KA50_VERSION__  then
 --       Gui.SetIcon(mainPath..'../FUI/BS-1.ico')
    else
        Gui.SetIcon(mainPath..'../FUI/DCS-1.ico')
    end
end

local function createUsersDirs()
	lfs.mkdir(userDataDir)
	lfs.mkdir(configPath)
	lfs.mkdir(tempDataDir)
	lfs.mkdir(tempMissionPath)
	lfs.mkdir(tempCampaignPath)
    lfs.mkdir(moviesDir)
	
	lfs.mkdir(userFiles.userMissionPath)
	lfs.mkdir(userFiles.userCampaignPath..'\\en')
	lfs.mkdir(userFiles.userCampaignPath..'\\ru')
	lfs.mkdir(userFiles.userTrackPath)
end

function createProgressBar()
	startProgressBar = require('startProgressBar')
	startProgressBar.create(0, 0, main_w, main_h)
	Gui.Redraw()
end


if NEW_GUI then
  loadSkin()
end

Gui = require('dxgui')
GuiWin = require('dxguiWin')

setmetatable(dxgui, {__index = dxguiWin})

loadTheme()
loadDatabase()  
loadOptions()
createGUI() 


-- поскольку fullscreen у нас не настоящий, то после вызова Gui.Create() нужно вызвать 
-- Gui.GetWindowSize(), который вернет настоящие размеры окна (для fullscreen это разрешение десктопа)
main_w, main_h = Gui.GetWindowSize()
createProgressBar()
startProgressBar.setValueProgress(1)
startProgressBar.setValueProgress(5)
createUsersDirs()
startProgressBar.setValueProgress(7)
createWaitScreen()
--loadDatabase()
startProgressBar.setValueProgress(8)
-- start music
music = require('me_music')
music.init('./Sounds')
music.setMusicVolume(panel_options.vdata.sound.music.__value__)
music.setEffectsVolume(panel_options.vdata.sound.gui.__value__)
music.start()

startProgressBar.setValueProgress(9)
panel_options.create(0, 0, main_w,  main_h)

startProgressBar.setValueProgress(10)

-- Создание главного меню
mmw = require('MainMenu')
mmw.create(0, 0, main_w, main_h)

-- Создание модулей
----Загружаем информацию о картах---------------------------
loaderMaps = require('loaderMaps')
--local dir = i18n.getLocalizedDirName(simPath .. 'TheatresOfWar/');  
local dir = simPath .. 'TheatresOfWar/';  
--base.print('dir=',dir,'path=',path)

--делаем английскую локализацию для неизвестных локалей
--if (dir == nil)  or (dir..'/' == path ) then
--	dir = path .. '/en'
--end

	
loaderMaps.loadDir(dir)	
startProgressBar.setValueProgress(11)
------------------------------------------------------------


-- Модуль edTerrain - это библиотека Робустова из проекта Black Shark.
-- Она обеспечивает доступ к отображаемому на память файлу модели 
-- земной поверхности Land.lsa2 и позволяет получать высоту местности
-- в заданной точке карты.
-- В библиотеку edTerrain специально внесены изменения в интересах
-- данного проекта, чтобы обеспечить доступ к ней из Lua.
-- В данном проекте эта библиотека называется lua-edTerrain.dll.
-- Поскольку она зависит от библиотек Common.dll и Math.dll, эти
-- библиотеки также включены в данный проект.


Terrain = require('edTerrain')


Gui.SetGCFramesCount(40)

--pluginsForm = require('me_pluginsForm')
MapWindow = require('me_map_window')
menubar = require('me_menubar')
toolbar = require('me_toolbar')
statusbar = require('me_statusbar')
--panel_message = require('me_message')
--panel_events = require('me_events')
panel_coalitions = require('me_coalitions')
panel_manager_resource = require('me_manager_resource')
panel_aircraft = require('me_aircraft')
--panel_helicopter = require('me_helicopter')
panel_ship = require('me_ship')
panel_vehicle = require('me_vehicle')
panel_summary = require('me_summary')
panel_SCR522 = require('me_panelSCR522')
panel_triggered_actions = require('me_triggered_actions')
panel_targeting = require('me_targeting')
panel_route = require('me_route')
panel_wpt_properties = require('me_wpt_properties')
panel_actions = require('me_action_edit_panel')
panel_action_condition = require('me_action_condition')
panel_loadout = require('me_loadout')
panel_payload = require('me_payload')
panel_fix_points = require('me_fix_points')
panel_nav_target_points = require('me_nav_target_points')
panel_static = require('me_static')
panel_warehouse = require('me_warehouse')
panel_navpoint = require('me_navpoint')
panel_bullseye = require('me_bullseye')
panel_quickstart = require('me_quickstart')

panel_weather = require('me_weather')
panel_map_options = require('me_map_options')
panel_mis_options = require('me_misoptions')
module_mission = require('me_mission')
panel_briefing = require('me_briefing')
panel_autobriefing = require('me_autobriefing');
panel_debriefing = require('me_debriefing')
panel_openfile = require('me_openfile')
panel_file_dialog = require('me_file_dialog')
panel_record_avi = require('record_avi')
panel_failures = require('me_failures')
panel_enc = require('me_encyclopedia')
panel_about = require('me_about')
panel_goal = require('me_goal')
panel_roles = require('me_roles')
MGModule = require('me_generator')

startProgressBar.setValueProgress(12)

GDData = require('me_generator_dialog_data')
GDData.initData()
nodes_manager = require('me_nodes_manager')
nodes_manager.initNodes()
templates_manager = require('me_templates_manager')
templates_manager.initData()
panel_generator = require('me_generator_dialog')
panel_generator_simple = require('me_simple_generator_dialog')

panel_trigrules = require('me_trigrules')
panel_zone = require('me_trigger_zone')
panel_template = require('me_template')
panel_training = require('me_training')
panel_logbook = require('me_logbook')
panel_campaign = require('me_campaign')
panel_units_list = require('me_units_list')
panel_trig_zones_list = require('me_trig_zones_list')
panel_campaign_editor = require('me_campaign_editor');
panel_campaign_end = require('me_campaignend');
exit_dialog = require('me_exit_dialog');
mod_copy_paste = require('me_copy_paste');
videoPlayer = require("me_video_player")
panel_news = require('me_news')
panel_infoPlugin = require('me_infoPlugin')
--panel_modulesmanager = require('me_modulesmanager')

local planner_mission = false

--debriefing_utils = require('debriefing_utils')

U = require('me_utilities')

-- Фиксированные размеры панелей Редактора миссий
top_toolbar_h = U.top_toolbar_h            
left_toolbar_w = U.left_toolbar_w           
bottom_toolbar_h = U.bottom_toolbar_h         
right_toolbar_w = U.right_toolbar_w 
map_w = main_w - left_toolbar_w        
local right_toolbar_h = U.right_toolbar_h 
actions_toolbar_w = U.actions_toolbar_w
actions_bar_h = (main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h) * 1.2
condition_bar_h = main_h - top_toolbar_h - bottom_toolbar_h  - actions_bar_h

-- Глобальная таблица сопрограмм, пинаемых между кадрами отрисовки
-- в функции updateWorld().
mapListCount = 0
loaded = 0

startProgressBar.setValueProgress(13)
-- Функция начальной инициализации симулятора.
-- Она модифицирует состояние прогресс-бара заставки.
-- Все диалоги создаются заранее, чтобы затем не тратить время при 
-- переключении между ними.
-- Данная функция изначально предполагала загрузку карты по листам с синхронным
-- перемещением прогресс-бара. Однако, когда листы упаковали в архив,
-- доступа к количеству обработанных листов не стало. Кроме того, после собственной
-- загрузки редактор еще достаточно долго ждет окончания загрузки симулятора. 
-- Поэтому ползунок теперь скачет большими шагами. Нормализовать это дело можно
-- только путем организации специальных обратных связей с модулями загрузки дорожной сети, 
-- карты и симулятора.
function loading()
	--panel_modulesmanager.create(0, 0, main_w, main_h);
startProgressBar.setValueProgress(15) 
    --backupTrackMission();
	--pluginsForm.create( 0, 0, main_w/2, main_h/2)
    -- Создание окна карты
    MapWindow.create(left_toolbar_w, top_toolbar_h, main_w - left_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h + 1)
startProgressBar.setValueProgress(17) 
    menubar.create( 0, 0, main_w, top_toolbar_h )
startProgressBar.setValueProgress(18)	
    toolbar.create( 0, top_toolbar_h, left_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h+1 )
startProgressBar.setValueProgress(20)	
    panel_briefing.create(main_w - right_toolbar_w - 30, top_toolbar_h, right_toolbar_w + 30,  main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(22)	
    panel_autobriefing.create(0, 0, main_w, main_h);
startProgressBar.setValueProgress(23)	
    panel_debriefing.create(0, 0, main_w, main_h)
	
startProgressBar.setValueProgress(25)	
	
    --panel_coalitions.create(main_w - 390, top_toolbar_h, 390, main_h - top_toolbar_h - bottom_toolbar_h)
	panel_coalitions.create(left_toolbar_w + 1, top_toolbar_h, main_w-left_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h)    
startProgressBar.setValueProgress(27)	
    panel_openfile.create(main_w - 390, 0, 390, main_h)
    panel_file_dialog.create((main_w - 474)/2, (main_h - 474)/2, 390, main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(29)	
    panel_record_avi.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(31)	
    panel_enc.create(0, 0,  main_w, main_h)
startProgressBar.setValueProgress(33)	
    panel_about.create(main_w - 390, top_toolbar_h, 390,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(35)	
    panel_failures.create(main_w - 650, top_toolbar_h + right_toolbar_h, 650,  main_h - top_toolbar_h - bottom_toolbar_h - right_toolbar_h) 
startProgressBar.setValueProgress(37)	
    panel_weather.create(main_w - 390, top_toolbar_h, 390,  main_h - top_toolbar_h - bottom_toolbar_h) 
	
startProgressBar.setValueProgress(39)   
 
    panel_training.create(0, 0, main_w, main_h)
startProgressBar.setValueProgress(41)
    panel_campaign_editor.create(0, 0, main_w, main_h)
startProgressBar.setValueProgress(43)	

    statusbar.create(0, main_h-bottom_toolbar_h + 1, main_w, bottom_toolbar_h - 1)
startProgressBar.setValueProgress(45)	
    panel_map_options.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(47)	
    panel_logbook.create(0, 0, main_w, main_h)
startProgressBar.setValueProgress(49)	
    panel_mis_options.create(0, top_toolbar_h, main_w, main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(51)	
    panel_campaign.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(53)	
    panel_generator.create(0, 0, main_w, main_h)
startProgressBar.setValueProgress(55)	
    panel_generator_simple.create(0, 0, main_w, main_h)

startProgressBar.setValueProgress(57)
	
	panel_summary.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(59)	
	panel_SCR522.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(61)	
	panel_triggered_actions.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(63)	
    panel_targeting.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(64)	
    panel_route.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(65)	
    panel_wpt_properties.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
startProgressBar.setValueProgress(66)	
	panel_actions.create(main_w - right_toolbar_w - actions_toolbar_w, main_h - bottom_toolbar_h - actions_bar_h, right_toolbar_w,  actions_bar_h)		
startProgressBar.setValueProgress(67)	
	panel_action_condition.create(main_w - right_toolbar_w - actions_toolbar_w, main_h - bottom_toolbar_h - actions_bar_h - condition_bar_h, right_toolbar_w, condition_bar_h)
startProgressBar.setValueProgress(68)	
    panel_loadout.create(left_toolbar_w + 1, top_toolbar_h, main_w-left_toolbar_w-right_toolbar_w - 1,  main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(69)	
    panel_payload.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
    panel_fix_points.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
	
startProgressBar.setValueProgress(70)	
	
    panel_nav_target_points.create(main_w - right_toolbar_w, top_toolbar_h + right_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h  - right_toolbar_h)
    panel_aircraft.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, right_toolbar_h)
startProgressBar.setValueProgress(71)	
   -- panel_helicopter.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, right_toolbar_h)
    panel_ship.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, right_toolbar_h)
startProgressBar.setValueProgress(72)	
    panel_vehicle.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, right_toolbar_h)
startProgressBar.setValueProgress(73)	
    panel_static.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(74)	
    panel_warehouse.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(75)	
    panel_manager_resource.create(main_w - 910+left_toolbar_w+1, top_toolbar_h, 910-left_toolbar_w-1-panel_warehouse.win_width, main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(76)	
	panel_navpoint.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h)	
startProgressBar.setValueProgress(77)	
	panel_bullseye.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w, main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(78)	
    panel_quickstart.create(main_w, main_h)
startProgressBar.setValueProgress(79)	
	panel_goal.create(0, top_toolbar_h, main_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
    panel_roles.create(0, top_toolbar_h, main_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
	
startProgressBar.setValueProgress(80)	
    panel_trigrules.create(0, top_toolbar_h, main_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(82)
    panel_zone.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(83)	
    panel_template.create(main_w - right_toolbar_w, top_toolbar_h, right_toolbar_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(85)	
    panel_units_list.create(left_toolbar_w, main_h - bottom_toolbar_h - 300, main_w - right_toolbar_w - left_toolbar_w,  300);
startProgressBar.setValueProgress(87)	
    panel_trig_zones_list.create(left_toolbar_w, main_h - bottom_toolbar_h - 300, main_w - right_toolbar_w - left_toolbar_w,  300);
startProgressBar.setValueProgress(88)	
    panel_campaign_end.create(0, 0, main_w, main_h);
startProgressBar.setValueProgress(89)	
    exit_dialog.create(main_w, main_h);
 
startProgressBar.setValueProgress(90)
 
    templates_manager.init(0, top_toolbar_h, main_w,  main_h - top_toolbar_h - bottom_toolbar_h)
startProgressBar.setValueProgress(91)	
    nodes_manager.setParams(0, top_toolbar_h, main_w,  main_h - top_toolbar_h - bottom_toolbar_h) 
startProgressBar.setValueProgress(92)    
    module_mission.create()
startProgressBar.setValueProgress(95)	
    --U.traverseTable(START_PARAMS);
    
    function trimQuotes(str)
        if string.find(str, '^"') and string.find(str, '"$') then
            local res = string.sub(str, 2, -2);
            return res;
        else
            return str;
        end        
    end;
    
    local realMissionName;
    START_PARAMS.missionPath = trimQuotes(START_PARAMS.missionPath);
    if START_PARAMS.missionPath and ('' ~= START_PARAMS.missionPath) then

        realMissionName = START_PARAMS.realMissionPath;
        --print('realMissionName',realMissionName);
        realMissionName = trimQuotes(realMissionName or '');
        --print('realMissionName',realMissionName);
        module_mission.load(START_PARAMS.missionPath, true); -- надо грузить временную миссию, так как туда записано имя пилота из логбука
        --module_mission.load(realMissionName, true);
        module_mission.mission.path = realMissionName;
		MISSION_PATH = realMissionName
        statusbar.setFileName(U.extractFileName(realMissionName));
    else
        local path = tempDataDir .. tempMissionName;
        print('removing', path);
        os.remove(path);
        module_mission.clearTempFolder();
    end;
 
startProgressBar.setValueProgress(96)
 
    if '' == START_PARAMS.returnScreen then 
        mmw.show(true);
    elseif START_PARAMS.returnScreen == 'training' then
        module_mission.create_new_mission();
        panel_training.show(true, realMissionName);
    elseif 'prepare' == START_PARAMS.returnScreen  then
        if realMissionName == nil then
            print('realMissionName == nil');
            return;
        end;
        module_mission.copyMission(realMissionName, START_PARAMS.missionPath);
        module_mission.load(realMissionName, true);
        
        MapWindow.show(true)
        menubar.show(true)
        toolbar.show(true)
        statusbar.show(true)
	elseif 'record_avi' == START_PARAMS.returnScreen then
		module_mission.create_new_mission();
		MapWindow.show(true)
		menubar.show(true)
		toolbar.show(true)
		statusbar.show(true)
		panel_record_avi.show(true)
    elseif 'LOFAC' == START_PARAMS.returnScreen  then
        if START_PARAMS.missionPath ~= '' then
            panel_debriefing.returnScreen = START_PARAMS.returnScreen;
            panel_debriefing.show(true)
        else
            MapWindow.show(true)
            menubar.show(true)
            toolbar.show(true)
            statusbar.show(true)
        end
    elseif 'LoadAndBriefing' == START_PARAMS.returnScreen  then
        local path = START_PARAMS.missionPath  
        START_PARAMS.returnScreen = ""
        
        mmw.show(false);        
        toolbar.b_open:setState(false)
        statusbar.t_file:setText(U.extractFileName(path));
        wait_screen.show(true);
            panel_autobriefing.missionFileName = path
            panel_autobriefing.returnToME = false;
                -- грузим миссию без редактора
            --print('Loading mission ', path)
            if module_mission.load(path, true) then
                panel_autobriefing.show(true, 'openmission');
            else
                mmw.show(true); 
            end;

        wait_screen.show(false);
    else
        panel_debriefing.returnScreen = START_PARAMS.returnScreen;
        panel_debriefing.show(true)
    end;
    

    --collectgarbage('collect')
    -- wait_screen.show(false)
    --os.setlocale("C")

end

-------------------------------------------------------------------------------
function setPlannerMission(pm)
	planner_mission = pm
end

-------------------------------------------------------------------------------
function isPlannerMission()
	return planner_mission
end

function setInputProcessor(_inputProcessor)    
    inputProcessor = _inputProcessor;
end; 

function getInputProcessor()    
    return inputProcessor;
end; 


-- Данная функция будет вызываться на каждом кадре отрисовки GUI.          
function Update()
    music.update()	

    if inputProcessor ~= nil then
        inputProcessor();
    end;
  -- Процесс начальной загрузки

	
	realTime  = os.clock()
    realClock = realTime * 1000
	
	if lastClock then
		panel_news.updateAnimations(realClock - lastClock)
	end
	lastClock = realClock

    if realTimePrev then
      if realTime - realTimePrev >= 1 then		
		
       if statusbar.form and statusbar.form.window then
      -- Выполняем ежесекундные работы.
      -- Подкручиваем часики в соответствующих диалогах, если они имеются
          realTimePrev = realTime
          if statusbar.form.window:isVisible() then
            local ddata = os.date()
            ddata = string.sub(ddata, 1 , string.len(ddata)-3)
            statusbar.form.t_clock:setText(ddata)
          end
       end
     end
    else
      realTimePrev = realTime
    end
	

    if NEW_GUI then
      Terrain.task_results()
    end  
end

Gui.SetUpdateCallback(Update)

function restartME()
    START_PARAMS.command = '';
    START_PARAMS.missionPath = '';
    if LOFAC == true then
        START_PARAMS.returnScreen = 'LOFAC';
        RETURN_SCREEN = 'LOFAC';
    else
        START_PARAMS.returnScreen = '';
        RETURN_SCREEN = '';
    end;
    MISSION_PATH = '';
    Gui.doQuit();    
end; 

local pressedKeys = {}

function collectMELoggingKeys(key, keyState)
  if 'left ctrl' == key or 'left shift' == key or 'left alt' == key or 'l' == key then
    if 'down' == keyState then
      pressedKeys[key] = true
    else
      pressedKeys[key] = false
    end
  end   
end

function processMELogging(key, keyState)  
  -- left ctrl + L - turn on log
  -- left ctrl + left shift + L - turn off log
  -- left ctrl + left shift + left alt + L - open log
  collectMELoggingKeys(key, keyState)
  
  if 'down' == keyState then
    if pressedKeys['left ctrl'] and pressedKeys['l'] then
      if pressedKeys['left shift'] then
        if pressedKeys['left alt'] then
          openLog()
        else
          turnLog(false);
        end
      else
        turnLog(true);
      end
    end
  end
end

-- все события от кнопок сначала попадают сюда
Gui.SetKeyboardCallback(processMELogging)

function writeLog()
    turnLog(false);
    if #hookLog >0 then
        local date = os.date();
        date = string.gsub(date, '[/:]','-');
        local logName = './temp/MissionEditor-' .. date ..'.log';
        print('saving log', logName);
        local f, err = io.open(logName, 'w');
        if f == nil then
            print(err)
        end;
        --f:write('local log = {\n');
        for i, rec in ipairs(hookLog) do
            -- f:write(string.format("{ src = %s, line = %d, fun = %s, time = %f },\n", 
                -- rec.short_src,
                -- rec.currentline,
                -- rec.fun,
                -- rec.time));
            f:write(rec..'\n'); 
        end;
        --f:write('}\n');
        f:close();
    end;    
end; 

function turnLog(b)
    print('turning log', b);
    
    if b then
        debug.sethook ( hookFcn, 'c' );
        --profiler.start();
    else
        debug.sethook ( );
        --profiler.stop();
    end;
end;

function openLog()
  print('openLog()')
  
  local folder = lfs.writedir() .. 'Logs'

  os.execute(string.format('explorer "%s"', folder))
end

function onQuit()
  if exit_dialog.show(true) then
    local NewInput = require('NewInput')
    MapWindow.show(false)
    Gui.doQuit()
  end
end; 

Gui.SetQuitCallback(onQuit)

function Gui.doQuit()  
  local NewInput = require('NewInput')  
  
  NewInput.uninitialize()  
  MGModule.saveAll()
  
  if Terrain then
	 Terrain.Release()
  end
  Gui.Quit()
end

function backupTrackMission()
    local dir = 'temp\\history';
    if not lfs.dir(dir)() then
        print('creating history dir '..dir)
        local res, err = lfs.mkdir(dir);
        print('lfs: ',res, err);
    end;

    -- local mission = io.open(mainPath .. '/temp/' .. tempMissionName, 'rb')
    -- if mission == nil then
        -- return;
    -- end;
    local timeTbl = os.date('*t');
    local timeStr = tostring(timeTbl.month) .. '-' .. tostring(timeTbl.day) ..
        '-' .. tostring(timeTbl.hour) .. '-' .. tostring(timeTbl.min) .. 
        '-' .. tostring(timeTbl.sec);

    local source = 'temp\\' .. tempMissionName;
    local dest = dir .. '\\tempMission_' .. timeStr .. '.miz';
    local str = string.format('copy %s %s >> nul', source, dest);
    print(str);
    os.execute(str);
    
    local source = 'temp\\' .. trackFileName;
    local dest = dir .. '\\LastMissionTrack_' .. timeStr .. '.trk';
    local str = string.format('copy %s %s >> nul', source, dest);
    print(str);
    os.execute(str);
    --mission:close()

    local source = 'temp\\debrief.log';
    local dest = dir .. '\\debrief_' .. timeStr .. '.log';
    local str = string.format('copy %s %s >> nul', source, dest);
    print(str);
    os.execute(str);
    
    -- local data  = mission:read('*a')    
    -- if data == nil then
        -- return;
    -- end;
    
    -- local dest = dir .. tempMissionName;
    -- local file = io.open(dest, 'wb')
    -- if file then        
        -- file:write(data)
        -- file:close();
    -- end

end; 

panel_news:updateNews()

function createListsUnitsPlugins()
	--[[ ненуна
	flyablesLAInPlugins = {}
	enableModules = {}
	for k,v in pairs(plugins) do
		enableModules[v.id] = v.applied
		for kk,vv in pairs(v.flyables) do
			if (flyablesLAInPlugins[vv.name] == nil) then
				flyablesLAInPlugins[vv.name] = v.id
			else
				print("ERROR conflict name:", vv.name,v.id)
			end	
		end
	end]]
	--U.traverseTable(flyablesLAInPlugins,2)

	botsLAInPlugins = {}
	enableModules = {}
	for k,v in pairs(plugins) do
		enableModules[v.id] = v.applied
		for kk,vv in pairs(v.units.aircrafts) do
			if (botsLAInPlugins[vv.name] == nil) then
				botsLAInPlugins[vv.Name] = v.id
			else
				print("ERROR conflict name:", vv.name,v.id)
			end		
		end
	end
	--U.traverseTable(botsLAInPlugins,2)


	technicsInPlugins = {}
	for k,v in pairs(plugins) do	
		for kk,vv in pairs(v.units.technics) do
			if (botsLAInPlugins[vv.name] == nil) then
				technicsInPlugins[vv.Name] = v.id
			else
				print("ERROR conflict name:", vv.name,v.id)
			end	
		end
	end
	--U.traverseTable(technicsInPlugins,2)
	--print("-------------------------------")
end
	
createListsUnitsPlugins()
loading()

-- выгружаем картинку задника
Gui.SetBackground()
Gui.SetWaitCursor(false)
--Gui.EnableDebugDraw(true)  -- DEBUG


startProgressBar.setValueProgress(100)
Gui.Run()


writeLog()
