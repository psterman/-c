export namespace main {
	
	export class AppInfo {
	    appName: string;
	    version: string;
	    buildMode: string;
	    bridgeOnly: boolean;
	
	    static createFrom(source: any = {}) {
	        return new AppInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.appName = source["appName"];
	        this.version = source["version"];
	        this.buildMode = source["buildMode"];
	        this.bridgeOnly = source["bridgeOnly"];
	    }
	}

}

export namespace poc {
	
	export class ProviderCapability {
	    provider: string;
	    stream: boolean;
	    action: boolean;
	    abort: boolean;
	    routes: string[];
	    experimental: boolean;
	    description?: string;
	
	    static createFrom(source: any = {}) {
	        return new ProviderCapability(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.provider = source["provider"];
	        this.stream = source["stream"];
	        this.action = source["action"];
	        this.abort = source["abort"];
	        this.routes = source["routes"];
	        this.experimental = source["experimental"];
	        this.description = source["description"];
	    }
	}
	export class HubStatus {
	    addr: string;
	    path: string;
	    a2uiProvider: string;
	    providerCapability: ProviderCapability;
	    running: boolean;
	    clientCount: number;
	    pumpRunning: boolean;
	    eventsEmitted: number;
	    lastEventSeq: number;
	
	    static createFrom(source: any = {}) {
	        return new HubStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.addr = source["addr"];
	        this.path = source["path"];
	        this.a2uiProvider = source["a2uiProvider"];
	        this.providerCapability = this.convertValues(source["providerCapability"], ProviderCapability);
	        this.running = source["running"];
	        this.clientCount = source["clientCount"];
	        this.pumpRunning = source["pumpRunning"];
	        this.eventsEmitted = source["eventsEmitted"];
	        this.lastEventSeq = source["lastEventSeq"];
	    }
	
		convertValues(a: any, classs: any, asMap: boolean = false): any {
		    if (!a) {
		        return a;
		    }
		    if (a.slice && a.map) {
		        return (a as any[]).map(elem => this.convertValues(elem, classs));
		    } else if ("object" === typeof a) {
		        if (asMap) {
		            for (const key of Object.keys(a)) {
		                a[key] = new classs(a[key]);
		            }
		            return a;
		        }
		        return new classs(a);
		    }
		    return a;
		}
	}
	
	export class ShellFtbStatus {
	    visible: boolean;
	    mounted: boolean;
	    ready: boolean;
	    entry: string;
	    htmlUrl: string;
	    scriptRoot: string;
	    updatedAt: string;
	    phase: number;
	    presentationMode: string;
	
	    static createFrom(source: any = {}) {
	        return new ShellFtbStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.visible = source["visible"];
	        this.mounted = source["mounted"];
	        this.ready = source["ready"];
	        this.entry = source["entry"];
	        this.htmlUrl = source["htmlUrl"];
	        this.scriptRoot = source["scriptRoot"];
	        this.updatedAt = source["updatedAt"];
	        this.phase = source["phase"];
	        this.presentationMode = source["presentationMode"];
	    }
	}

}

