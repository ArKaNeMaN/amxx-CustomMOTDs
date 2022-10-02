#include <amxmodx>
#include <json>

#pragma semicolon 1
#pragma compress 1

#define RegisterPluginByVars() do { \
    if (GetAmxxVersionNum() < 1100) { \
        register_plugin(PluginName, PluginVersion, PluginAuthor); \
    } \
} while(is_linux_server() == 0xDEADBEEF)

public stock const PluginName[] = "Custom MOTDs";
public stock const PluginVersion[] = "1.1.0";
public stock const PluginAuthor[] = "ArKaNeMaN";
public stock const PluginURL[] = "t.me/arkaneman";

enum MotdType{
    MT_Undefined = -1,

    MT_File = 0,
    MT_Site,
}

enum _:E_MotdData{
    MD_Title[128],
    MotdType:MD_Type,
    MD_Url[PLATFORM_MAX_PATH],
}

new Trie:tMotds;

public plugin_init() {
    RegisterPluginByVars();

    tMotds = LoadMotds();
    register_srvcmd("custom_motds_reload", "@SrvCmd_ReloadConfig");

    server_print("[%s v%s] loaded.", PluginName, PluginVersion);
}

@SrvCmd_ReloadConfig() {
    TrieDestroy(tMotds);
    tMotds = LoadMotds();
}

@Cmd_ShowMOTD(const UserId) {
    static Cmd[32];
    GetCmd(Cmd, charsmax(Cmd));

    if (!TrieKeyExists(tMotds, Cmd)) {
        return PLUGIN_CONTINUE;
    }

    static Motd[E_MotdData];
    TrieGetArray(tMotds, Cmd, Motd, E_MotdData);

    switch (Motd[MD_Type]) {
        case MT_File: {
            show_motd(UserId, Motd[MD_Url], Motd[MD_Title]);
        }
        
        case MT_Site: {
            static Content[1024];
            formatex(Content, charsmax(Content), "\
                <!DOCTYPE HTML>\
                <html>\
                    <head>\
                        <meta http-equiv=^"refresh^" content=^"0;url=%s^">\
                    </head>\
                </html>\
            ", Motd[MD_Url]);
            show_motd(UserId, Content, Motd[MD_Title]);
        }
    }

    return PLUGIN_HANDLED;
}

Trie:LoadMotds(Trie:tMotds = Invalid_Trie) {
    new file[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", file, charsmax(file));
    add(file, charsmax(file), "/plugins/CustomMOTDs.json");
    if (!file_exists(file)) {
        set_fail_state("[ERROR] Config file '%s' not found", file);
        return tMotds;
    }

    new JSON:List = json_parse(file, true);
    if (!json_is_object(List)) {
        json_free(List);
        set_fail_state("[ERROR] Invalid config structure. File '%s'", file);
        return tMotds;
    }
    
    if (tMotds == Invalid_Trie) {
        tMotds = TrieCreate();
    }

    new Cmd[32], JSON:Item, Data[E_MotdData], temp[32];
    for (new i = 0; i < json_object_get_count(List); i++) {
        json_object_get_name(List, i, Cmd, charsmax(Cmd));

        Item = json_object_get_value(List, Cmd);
        if (!json_is_object(Item)) {
            log_amx("[ERROR] [ERROR] Invalid config structure. File '%s'. Item '%s' skipped.", file, Cmd);
            json_free(Item);
            continue;
        }

        json_object_get_string(Item, "Type", temp, charsmax(temp));
        Data[MD_Type] = GetMOTDType(temp);
        if (!Data[MD_Type]) {
            log_amx("[ERROR] Undefined MOTD type '%s'. Item '%s' skipped.", temp, Cmd);
            json_free(Item);
            continue;
        }

        json_object_get_string(Item, "Url", Data[MD_Url], charsmax(Data[MD_Url]));
        if (Data[MD_Type] == MT_File && !file_exists(Data[MD_Url])) {
            log_amx("[ERROR] MOTD file '%s' not found. Item '%s' skipped.", Data[MD_Url], Cmd);
            json_free(Item);
            continue;
        }

        json_object_get_string(Item, "Title", Data[MD_Title], charsmax(Data[MD_Title]));

        TrieSetArray(tMotds, Cmd, Data, E_MotdData);

        RegisterClCmds(Cmd, "@Cmd_ShowMOTD");

        json_free(Item);
    }
    json_free(List);

    return tMotds;
}

RegisterClCmds(const Cmd[], const Handler[]) {
    register_clcmd(Cmd, Handler);
    register_clcmd(fmt("say /%s", Cmd), Handler);
    register_clcmd(fmt("say_team /%s", Cmd), Handler);
}

bool:GetCmd(Output[], len) {
    static cmd[64];
    read_argv(0, cmd, charsmax(cmd));
    if (equal(cmd, "say") || equal(cmd, "say_team")) {
        read_argv(1, cmd, charsmax(cmd));
        if (cmd[0] == '/') {
            formatex(Output, len, cmd[1]);
            return true;
        }
    } else {
        formatex(Output, len, cmd);
        return true;
    }
    return false;
}

MotdType:GetMOTDType(const Str[]) {
    if (equali(Str, "File")) {
        return MT_File;
    } else if (equali(Str, "Site")) {
        return MT_Site;
    } else {
        return MT_Undefined;
    }
}

// https://github.com/Nord1cWarr1or/Universal-AFK-Manager/blob/6272afbb8c27f8b7ad770e3036b5960042001e6b/scripting/UAFKManager.sma#L298-L321
stock GetAmxxVersionNum() {
    static iRes;
    if (iRes) {
        return iRes;
    }

    new sAmxxVer[16];
    get_amxx_verstring(sAmxxVer, charsmax(sAmxxVer));

    if (strfind(sAmxxVer, "1.10.0") != -1) {
        iRes = 1100;
    } else if (strfind(sAmxxVer, "1.9.0") != -1) {
        iRes = 190;
    } else if (strfind(sAmxxVer, "1.8.3") != -1) {
        iRes = 183;
    } else if (strfind(sAmxxVer, "1.8.2") != -1) {
        iRes = 182;
    } else {
        iRes = 1;
    }

    return iRes;
}
