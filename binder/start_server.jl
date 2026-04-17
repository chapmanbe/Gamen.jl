import Pluto

@assert haskey(ENV, "JSP_PORT")

Pluto.run(;
    host="0.0.0.0",
    port=parse(Int64, ENV["JSP_PORT"]),

    # Julia compiler options
    pkgimages="no",
    optimize=1,

    # Security — Binder handles authentication
    require_secret_for_open_links=false,
    require_secret_for_access=false,
    warn_about_untrusted_code=false,

    # UI options for Binder
    launch_browser=false,
    dismiss_update_notification=true,
    show_file_system=false,
)
