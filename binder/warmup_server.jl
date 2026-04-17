@info "Instantiate binder environment..."
import Pkg
Pkg.instantiate()

@info "Import Pluto..."
import Pluto

@info "Starting warmup notebook..."
sesh = Pluto.ServerSession(options=Pluto.Configuration.from_flat_kwargs(;
    pkgimages="no",
    optimize=1,
    require_secret_for_open_links=false,
    require_secret_for_access=false,
    warn_about_untrusted_code=false,
    launch_browser=false,
    dismiss_update_notification=true,
    show_file_system=false,
))
nb = Pluto.SessionActions.new(sesh; run_async=false)

@info "Shutting down warmup notebook..."
Pluto.SessionActions.shutdown(sesh, nb; async=false)
@info "Warmup done."
