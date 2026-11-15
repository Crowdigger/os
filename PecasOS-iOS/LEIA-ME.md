# Peças OS — versão nativa para iPhone e iPad

Aplicativo iOS escrito em **SwiftUI** (não é site ou PWA). Mantém o conceito do aplicativo Android, com visual inspirado no Windows Phone: azul, laranja, branco, verde e modo escuro.

## Requisitos

- Ambiente macOS com **Xcode compatível com iOS 17+** e iOS 17+ como destino do aplicativo.
- iPhone ou iPad com iOS/iPadOS 17 ou superior para instalar e testar.
- Conta Apple configurada em **Xcode > Settings > Accounts**. Uma conta gratuita pode ser usada para testes em dispositivo com restrições; distribuição para terceiros/App Store requer assinatura/provisionamento apropriados.

## Abrir, testar e instalar

1. Descompacte o ZIP em um Mac.
2. Abra `PeçasOS.xcodeproj` com Xcode.
3. Em **Signing & Capabilities**, selecione seu Team e, se necessário, altere o Bundle Identifier.
4. Conecte um iPhone e selecione-o como destino de execução.
5. Clique em **Run** (▶) para compilar e instalar.
6. Para distribuição, use **Product > Archive** e siga as opções de assinatura/exportação do Xcode.

## Funções incluídas

- Pesquisa por número de OS e nome de cliente.
- Cadastro em quatro etapas: número da OS e cliente; local; fotos da peça (1 a 5 obrigatórias); foto opcional da ficha de execução.
- Tirar foto com a câmera ou escolher da galeria.
- Compactação JPEG automática: peça até 1920 px / qualidade 85%; ficha até 2400 px / qualidade 88%.
- Data e horário de criação preservados na edição; cópias recebem data nova.
- Duplicação com cópias independentes de fotos, edição e exclusão com confirmação.
- Persistência offline no armazenamento privado do aplicativo e modo claro/escuro.
- Backup/restauração manual em arquivo ZIP por meio do app Arquivos (iCloud Drive ou armazenamento local), com confirmação antes de substituir dados.

## Observações

- O projeto **ainda não foi compilado nem executado no Xcode**, pois o ambiente de desenvolvimento disponível aqui não é macOS.
- Dados do Android **não são sincronizados automaticamente** com o iOS. Para migrar, exporte um backup ZIP manual no Android 1.5 e importe-o no iPhone, ou vice-versa.
- Os cadastros ficam no aparelho. Excluir o aplicativo pode excluir os dados. Faça um backup manual antes de desinstalar ou trocar de celular.
- **Backup manual incluído:** na tela inicial toque em **Salvar backup** e, no seletor Arquivos, escolha **iCloud Drive** ou **No Meu iPhone**. Para recuperar, toque em **Restaurar**, selecione o arquivo ZIP e confirme a substituição dos cadastros. **Não há backups automáticos.**
- O formato de backup `PecasOS-*.zip` é compatível com a versão Android 1.5: pode ser importado entre Android e iPhone pela função de restauração. O arquivo inclui números de OS, clientes, locais, horários e fotografias.
- **Privacidade:** este backup ZIP **não tem senha ou criptografia própria**. Escolha uma conta/armazenamento de confiança e siga as regras da empresa para dados de clientes.
- O backup foi validado quanto à estrutura ZIP, mas as telas nativas do iOS ainda precisam ser compiladas/testadas em um ambiente macOS com Xcode.
- O projeto inclui uma configuração básica de ícone; para publicação, substitua os assets do ícone do app por um ícone definitivo.
