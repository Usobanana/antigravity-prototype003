import http.server
import socket
import socketserver
import os
import sys
import qrcode
import ssl
from datetime import datetime, timedelta
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

PORT = 8000
DIRECTORY = "build/web"
CERT_FILE = "server.pem"
KEY_FILE = "key.pem"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

def get_ip_address():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def generate_self_signed_cert(ip_address):
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        return

    print(f"Generating self-signed certificate for {ip_address}...")
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, u"JP"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, u"Tokyo"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, u"Local"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, u"Dev Server"),
        x509.NameAttribute(NameOID.COMMON_NAME, u"localhost"),
    ])
    
    # Add localhost and the IP address to the SAN
    alt_names = [x509.DNSName(u"localhost")]
    if ip_address:
        alt_names.append(x509.IPAddress(ip_address))
        
    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.utcnow()
    ).not_valid_after(
        datetime.utcnow() + timedelta(days=365)
    ).add_extension(
        x509.SubjectAlternativeName(alt_names),
        critical=False,
    ).sign(key, hashes.SHA256())

    with open(KEY_FILE, "wb") as f:
        f.write(key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        ))
    with open(CERT_FILE, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))
    print("Certificate generated.")

def run():
    # Ensure the directory exists
    if not os.path.exists(DIRECTORY):
        print(f"Error: Directory '{DIRECTORY}' not found. Please export your Godot project to this folder.")
        print(f"  Export Path: {os.path.abspath(DIRECTORY)}/index.html")
        return

    ip = get_ip_address()
    
    # Pass IP to cert generator
    try:
        import ipaddress
        ip_obj = ipaddress.ip_address(ip)
    except ValueError:
        ip_obj = None
        
    generate_self_signed_cert(ip_obj)

    url = f"https://{ip}:{PORT}"
    
    print(f"Serving at: {url}")
    print("Scan the QR code below with your mobile device to play:")
    print("NOTE: You will see a security warning. Please bypass it (Details in walkthrough.md).")
    
    # Generate QR code
    qr = qrcode.QRCode()
    qr.add_data(url)
    qr.print_ascii(invert=True)
    
    httpd = socketserver.TCPServer(("", PORT), Handler)
    
    # Wrap with SSL
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")

if __name__ == "__main__":
    run()
