def setup_plutoserver():
    return {
        "command": ["sh", "start_server.sh"],
        "environment": {
            "JSP_PORT": "{port}",
        },
        "timeout": 120,
        "launcher_entry": {
            "title": "Pluto.jl",
        },
    }
