class FilterModule(object):
    def filters(self):
        return {'to_backend': self.create_backend_list}

    def create_backend_list(self, vals):
        backends = []
        for i in vals:
            backends.append({"name": i, "address": i+":6443"})
        return backends
