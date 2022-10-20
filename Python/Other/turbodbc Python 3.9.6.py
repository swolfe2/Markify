import dlltracer
import sys
with dlltracer.Trace(out=sys.stdout):
    import turbodbc