LIST        ?= blocked-sites
NGINXCONF   ?= sample-nginx.conf
CERTOUTFILE ?= certificate.crt
KEYOUTFILE  ?= private.key

TMPFILE      = tmpfile

read-list:
	@((grep -v '^#' $(LIST) | \
	grep -Eo '[a-z0-9-]+\.[a-z]{2,3}$$') && (grep -v '^#' $(LIST) | \
	grep '=$$' | awk '{print substr($$0,0,length($$0)-1)}')) | sort | uniq

nginx-rules:
	@make read-list | tr '\n' '|' | sed 's/\./\\./g' | \
	sed 's/\|$$//' | awk '{print "server_name \"~^(.*\\.)?("$$0")$$\";"}'

update-nginx-rules:
	@cat $(NGINXCONF) | sed "s/^\(.*\)server_name.*$$/\1$$(\
		make nginx-rules | sed 's/[\/&]/\\&/g')/" | tee $(NGINXCONF)

dnsmasq-rules:
	@read -p "IP address of your server? (127.0.0.1) " IP && \
	if [[ -z "$$IP" ]]; then IP="127.0.0.1"; fi && \
	make read-list | awk '{print "address=/"$$0"/'$$IP'"}'

acrylic-rules:
	@read -p "IP address of your server? (127.0.0.1) " IP && \
	if [[ -z "$$IP" ]]; then IP="127.0.0.1"; fi && \
	grep -v '^#' $(LIST) | grep -v '^$$' | awk '{sub(/=$$/,"",$$0);print "'$$IP' "$$0}'

openssl-config:
	@printf \
	"[req]\n"\
	"distinguished_name = req_distinguished_name\n"\
	"x509_extensions = v3_req\n"\
	"prompt = no\n"\
	"[req_distinguished_name]\n"\
	"C = CN\n"\
	"ST = Guangdong\n"\
	"L = Guangzhou\n"\
	"O = CGH.IO\n"\
	"OU = IT Department\n"\
	"CN = FUCK GFW!!!\n"\
	"[v3_req]\n"\
	"keyUsage = keyEncipherment, dataEncipherment\n"\
	"extendedKeyUsage = serverAuth\n"\
	"subjectAltName = @alt_names\n"\
	"[alt_names]\n"\
	"$$(cat $(LIST) | grep -v '^#' | grep -v '^$$' | sort | uniq | \
	awk '{gsub("=$$","",$$0); print "DNS."NR" = "$$0}')\n" > \
	$(TMPFILE)

generate-key-if-none:
	@test -f $(KEYOUTFILE) || openssl genrsa -out $(KEYOUTFILE) 4096 -sha512

self-signed-cert: openssl-config generate-key-if-none
	@openssl req -new -days 9999 -nodes -x509 -config $(TMPFILE) \
	-key $(KEYOUTFILE) -out $(CERTOUTFILE)
	@rm -f $(TMPFILE)
